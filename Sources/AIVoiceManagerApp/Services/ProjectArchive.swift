import Foundation

/// Export Project / Open Project… as one `.avmproject.zip`: the project folder as it is on disk
/// (`project.json` + `Takes/<id>/take.json` + `take.wav`), so another Mac gets the takes without generating again.
/// Zipped with macOS's own `/usr/bin/ditto`; read back with `/usr/bin/unzip -p` (zero dependencies).
enum ProjectArchive {
    static let fileExtension = "avmproject.zip"
    static let maxFile = 200_000_000          // one take.wav: ~70 min of 24 kHz mono
    static let maxTotal = 1_000_000_000       // everything read from one archive
    static let maxTakes = 200

    static func zip(_ folder: URL, to archive: URL) throws {
        try? FileManager.default.removeItem(at: archive)   // the save panel already asked about replacing it
        try run("/usr/bin/ditto", ["-c", "-k", "--norsrc", folder.path, archive.path])
    }

    /// Trust boundary: the zip comes from outside, so it is **never unpacked to disk**. Only `project.json` and
    /// `Takes/<id>/take.{json,wav}` (ids of letters, digits and `-`) are streamed out of it into memory, each
    /// stopped at its byte limit while reading — so no `..` path, symlink (`unzip -p` prints a link's text, never
    /// its target) or lying size header can reach the disk or exhaust memory.
    struct Reader {
        let archive: URL
        private(set) var budget = ProjectArchive.maxTotal

        init(_ archive: URL) { self.archive = archive }

        /// Every take folder in the archive whose name is safe to ask `unzip` for.
        func takeIDs() throws -> [String] {
            let listing = try run("/usr/bin/zipinfo", ["-1", archive.path], limit: 10_000_000)
            let names = String(bytes: listing, encoding: .utf8) ?? ""
            let ids = names.split(separator: "\n").compactMap { name in
                name.wholeMatch(of: /Takes\/([A-Za-z0-9-]{1,64})\/take\.wav/).map { String($0.1) }
            }
            return Array(ids.prefix(maxTakes))
        }

        /// One entry's bytes, or nil if it's missing or over its limit / the archive's remaining budget.
        mutating func data(_ name: String, limit: Int = ProjectArchive.maxFile) -> Data? {
            guard let data = try? run("/usr/bin/unzip", ["-p", archive.path, name], limit: min(limit, budget)),
                  !data.isEmpty else { return nil }
            budget -= data.count
            return data
        }
    }

    /// The imported project, cleaned field by field, and the ids of takes whose `take.json` reads back.
    static func read(_ reader: inout Reader, fallbackTitle: String)
        -> (draft: ProjectDraft, takes: [(Take, String)])? {
        guard let data = reader.data("project.json", limit: 10_000_000),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["items"] is [Any] || object["blocks"] is [Any] else { return nil }
        var takes: [(Take, String)] = []
        for id in (try? reader.takeIDs()) ?? [] {
            guard let json = reader.data("Takes/\(id)/take.json", limit: 10_000_000),
                  let take = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { continue }
            let created = (take["created"] as? String).flatMap { try? Date($0, strategy: .iso8601) } ?? .now
            let draft = clean(imported: take["draft"], fallbackTitle: fallbackTitle)
            takes.append((Take(id: "", created: created, duration: 0, draft: draft, mock: false), id))
        }
        return (clean(imported: object, fallbackTitle: fallbackTitle), takes.sorted { $0.0.created > $1.0.created })
    }

    /// Runs a system tool; its output is read in chunks and the tool is stopped past `limit` bytes.
    @discardableResult
    static func run(_ tool: String, _ arguments: [String], limit: Int = .max) throws -> Data {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        var data = Data()
        let handle = output.fileHandleForReading
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            guard data.count + chunk.count <= limit else {
                process.terminate()
                process.waitUntilExit()
                throw CocoaError(.fileReadTooLarge)
            }
            data.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
        return data
    }
}
