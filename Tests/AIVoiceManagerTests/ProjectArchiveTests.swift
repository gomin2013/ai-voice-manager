import XCTest
@testable import AIVoiceManagerApp

/// Open Project… reads a zip from outside without unpacking it: only known names, each under a byte limit.
@MainActor
final class ProjectArchiveTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "avm-zip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws { try? FileManager.default.removeItem(at: work) }

    /// A folder with a valid project.json, zipped by the same tool Export uses.
    private func zip(_ build: (URL) throws -> Void) throws -> URL {
        let source = work.appending(path: "src-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let project = ProjectFile(id: "x", opened: .now, draft: Fixtures.two)
        try ProjectStore.encoder.encode(project).write(to: source.appending(path: "project.json"))
        try build(source)
        let archive = work.appending(path: "\(UUID().uuidString).avmproject.zip")
        try ProjectArchive.zip(source, to: archive)
        return archive
    }

    private func addTake(_ id: String, wav: Data, to folder: URL) throws {
        let take = folder.appending(path: "Takes/\(id)")
        try FileManager.default.createDirectory(at: take, withIntermediateDirectories: true)
        try wav.write(to: take.appending(path: "take.wav"))
        let json = Take(id: id, created: .now, duration: 1, draft: Fixtures.single, mock: false)
        try ProjectStore.encoder.encode(json).write(to: take.appending(path: "take.json"))
    }

    func testASymlinkedTakesFolderIsNeverFollowed() throws {
        let archive = try zip { source in
            try FileManager.default.createSymbolicLink(at: source.appending(path: "Takes"),
                                                       withDestinationURL: URL(fileURLWithPath: "/etc"))
        }
        var reader = ProjectArchive.Reader(archive)
        let imported = try XCTUnwrap(ProjectArchive.read(&reader, fallbackTitle: "x"))
        XCTAssertEqual(imported.draft.title, Fixtures.two.title)
        XCTAssertTrue(imported.takes.isEmpty)
    }

    func testOnlySafeTakeNamesAreRead() throws {
        let archive = try zip { source in
            try addTake("2026-10-24-010203", wav: WAVTests.wav(seconds: 1), to: source)
            try addTake("odd name", wav: WAVTests.wav(seconds: 1), to: source)   // space: never asked for
        }
        XCTAssertEqual(try ProjectArchive.Reader(archive).takeIDs(), ["2026-10-24-010203"])
    }

    func testReadingStopsAtTheLimit() throws {
        let archive = try zip { try addTake("t", wav: WAVTests.wav(seconds: 1), to: $0) }   // 48 KB of samples
        var reader = ProjectArchive.Reader(archive)
        XCTAssertNil(reader.data("Takes/t/take.wav", limit: 10_000))
        XCTAssertNotNil(reader.data("Takes/t/take.wav"))
        XCTAssertNil(reader.data("Takes/missing/take.wav"))
    }

    func testNotAZipIsRefused() throws {
        let junk = work.appending(path: "junk.avmproject.zip")
        try Data("PK not really".utf8).write(to: junk)
        var reader = ProjectArchive.Reader(junk)
        XCTAssertNil(ProjectArchive.read(&reader, fallbackTitle: "x"))
    }
}
