import Foundation

/// Projects as plain files (ADR-011), Finder-readable:
/// `<root>/<id>/project.json` (the Export shape, so Open Project… reads it too) and
/// `<root>/<id>/Takes/<take id>/take.json` (+ `take.wav`, slice 3). Delete = Trash, so Undo can bring it back.
struct ProjectStore: Sendable {
    let root: URL

    /// `~/Library/Application Support/AI Voice Manager/Projects`
    static var standard: ProjectStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ProjectStore(root: support.appending(path: "AI Voice Manager/Projects", directoryHint: .isDirectory))
    }

    func folder(of id: String) -> URL { root.appending(path: id, directoryHint: .isDirectory) }

    /// Every readable project, newest opened first. A folder that doesn't decode is skipped, never deleted.
    func loadAll() -> [Project] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appending(path: "project.json")),
                  let file = try? Self.decoder.decode(ProjectFile.self, from: data) else { return nil }
            return Project(id: file.id, opened: file.opened, draft: file.draft, takes: loadTakes(of: file.id),
                           selection: nil)
        }
        .sorted { $0.opened > $1.opened }
    }

    func save(_ project: Project) throws {
        let folder = folder(of: project.id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = ProjectFile(id: project.id, opened: project.opened, draft: project.draft)
        try Self.encoder.encode(file).write(to: folder.appending(path: "project.json"), options: .atomic)
    }

    /// Moves the project folder to the Trash; the returned URL is where it went (for Undo).
    func trash(_ id: String) throws -> URL? {
        var trashed: NSURL?
        try FileManager.default.trashItem(at: folder(of: id), resultingItemURL: &trashed)
        return trashed as URL?
    }

    /// Undo of `trash`: the folder comes back from the Trash.
    func restore(_ id: String, from trashed: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: trashed, to: folder(of: id))
    }

    // MARK: Takes — `Takes/<take id>/take.json` + `take.wav`

    func takeFolder(_ takeID: String, of projectID: String) -> URL {
        folder(of: projectID).appending(path: "Takes/\(takeID)", directoryHint: .isDirectory)
    }

    func audio(of takeID: String, in projectID: String) -> URL {
        takeFolder(takeID, of: projectID).appending(path: "take.wav")
    }

    /// A folder name nobody has yet: `2026-10-24-001200` (+ `-2`, `-3` … within the same second).
    func newTakeID(at date: Date, in projectID: String) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")   // Western digits + Gregorian year, whatever the Mac uses
        format.dateFormat = "yyyy-MM-dd-HHmmss"
        let base = format.string(from: date)
        var id = base, number = 1
        while FileManager.default.fileExists(atPath: takeFolder(id, of: projectID).path) {
            number += 1
            id = "\(base)-\(number)"
        }
        return id
    }

    /// WAV first, then take.json; if either fails the folder goes, so a failed take leaves nothing behind.
    func saveTake(_ take: Take, wav: Data, in projectID: String) throws {
        let folder = takeFolder(take.id, of: projectID)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try wav.write(to: folder.appending(path: "take.wav"), options: .atomic)
            try Self.encoder.encode(take).write(to: folder.appending(path: "take.json"), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    func trashTake(_ takeID: String, of projectID: String) throws -> URL? {
        var trashed: NSURL?
        try FileManager.default.trashItem(at: takeFolder(takeID, of: projectID), resultingItemURL: &trashed)
        return trashed as URL?
    }

    func restoreTake(_ takeID: String, of projectID: String, from trashed: URL) throws {
        let folder = takeFolder(takeID, of: projectID)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: trashed, to: folder)
    }

    private func loadTakes(of id: String) -> [Take] {
        let takes = folder(of: id).appending(path: "Takes", directoryHint: .isDirectory)
        let folders = (try? FileManager.default.contentsOfDirectory(at: takes, includingPropertiesForKeys: nil)) ?? []
        return folders
            .compactMap { try? Self.decoder.decode(Take.self, from: Data(contentsOf: $0.appending(path: "take.json"))) }
            .sorted { $0.created > $1.created }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// ponytail: Export has no takes — their WAVs can't travel in one JSON; a folder / zip export when someone needs it
/// `project.json` and the Export file: the draft's fields at the top level (the prototype's `{app, version, ...draft}`)
/// plus the project's id and when it was last opened.
struct ProjectFile: Codable {
    var app = "AI Voice Manager"
    var version = 2
    let id: String
    let opened: Date
    let draft: ProjectDraft

    private enum CodingKeys: String, CodingKey { case app, version, id, opened }

    init(id: String, opened: Date, draft: ProjectDraft) {
        self.id = id
        self.opened = opened
        self.draft = draft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        opened = try container.decode(Date.self, forKey: .opened)
        draft = try ProjectDraft(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try draft.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(app, forKey: .app)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(opened, forKey: .opened)
    }
}
