import XCTest
@testable import AIVoiceManagerApp

@MainActor
final class ProjectStoreTests: XCTestCase {
    private var store: ProjectStore!

    override func setUp() async throws {
        LanguageService.shared.current = .english
        store = ProjectStore(root: FileManager.default.temporaryDirectory
            .appending(path: "avm-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: store.root)
    }

    private func project(_ id: String, opened: Date = .now, draft: ProjectDraft = Fixtures.two) -> Project {
        Project(id: id, opened: opened, draft: draft, takes: [], selection: nil)
    }

    func testSavedProjectsLoadBackNewestFirstAndJunkIsSkipped() throws {
        var repeated = Fixtures.two
        repeated.items[2] = .expr(ExpressionScene(id: "c", tag: .sigh, times: 3))
        try store.save(project("old", opened: Date(timeIntervalSince1970: 1_000), draft: Fixtures.single))
        try store.save(project("new", opened: Date(timeIntervalSince1970: 2_000), draft: repeated))
        let junk = store.folder(of: "junk")
        try FileManager.default.createDirectory(at: junk, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: junk.appending(path: "project.json"))

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.map(\.id), ["new", "old"])
        XCTAssertEqual(loaded[0].draft, repeated)
        XCTAssertEqual(loaded[0].opened, Date(timeIntervalSince1970: 2_000))
        XCTAssertTrue(FileManager.default.fileExists(atPath: junk.path))   // skipped, never deleted
    }

    /// Export = the project folder zipped, takes included; Open makes it a new project with fresh ids and the takes.
    func testZipExportCarriesTheTakesToANewProject() throws {
        let vm = EditorViewModel(projects: [project("p")], hasGeminiKey: false, store: store)
        let take = Take(id: "2026-10-24-010203", created: Date(timeIntervalSince1970: 5_000), duration: 3,
                        draft: Fixtures.single, mock: false)
        try store.saveTake(take, wav: WAVTests.wav(seconds: 1.5), in: "p")
        // a take whose "wav" isn't one is left out on Open
        try store.saveTake(Take(id: "fake", created: .now, duration: 9, draft: Fixtures.single, mock: false),
                           wav: Data("not audio".utf8), in: "p")
        let zip = store.root.deletingLastPathComponent().appending(path: "\(UUID().uuidString).avmproject.zip")
        defer { try? FileManager.default.removeItem(at: zip) }
        try vm.exportArchive(to: zip)

        XCTAssertTrue(vm.open(zip))
        XCTAssertEqual(vm.projects.count, 2)
        XCTAssertNotEqual(vm.currentID, "p")
        XCTAssertEqual(vm.draft.title, Fixtures.two.title)
        XCTAssertNotEqual(vm.draft.items.map(\.id), Fixtures.two.items.map(\.id))   // fresh ids
        let imported = try XCTUnwrap(vm.project.takes.first)
        XCTAssertEqual(vm.project.takes.count, 1)
        XCTAssertEqual(imported.duration, 1.5, accuracy: 0.001)                    // from the WAV, not the JSON
        XCTAssertEqual(imported.created, take.created)
        XCTAssertNotNil(vm.audio(of: imported))
        XCTAssertEqual(store.loadAll().first { $0.id == vm.currentID }?.takes.count, 1)   // and saved
    }

    func testJunkIsRefusedAndOldJsonStillOpens() throws {
        let vm = EditorViewModel(projects: [project("p")], hasGeminiKey: false, store: store)
        let junk = store.root.deletingLastPathComponent().appending(path: "\(UUID().uuidString).avmproject.zip")
        try Data("PK not really".utf8).write(to: junk)
        defer { try? FileManager.default.removeItem(at: junk) }
        XCTAssertFalse(vm.open(junk))
        XCTAssertFalse(vm.open(Data(#"{"title": "no timeline"}"#.utf8), fileName: "x.json"))
        XCTAssertEqual(vm.projects.count, 1)

        let json = try ProjectStore.encoder.encode(ProjectFile(id: "x", opened: .now, draft: Fixtures.two))
        XCTAssertTrue(vm.open(json, fileName: "B.avmproject.json"))
        XCTAssertEqual(vm.draft.title, Fixtures.two.title)
        XCTAssertEqual(vm.projects.count, 2)
    }

    func testEveryHistoryStepSaves() throws {
        let vm = EditorViewModel(projects: [project("p")], hasGeminiKey: false, store: store)
        vm.rename("Saved by itself")
        XCTAssertEqual(store.loadAll().first?.draft.title, "Saved by itself")
    }

    func testRemoveGoesToTheTrashAndUndoBringsItBack() throws {
        let vm = EditorViewModel(projects: [project("a"), project("b", opened: .distantPast)], hasGeminiKey: false,
                                 store: store)
        for project in vm.projects { try store.save(project) }
        vm.removeProject("b")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.folder(of: "b").path))
        XCTAssertEqual(vm.projects.map(\.id), ["a"])

        try XCTUnwrap(vm.notice?.undo)()
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.folder(of: "b").path))
        XCTAssertEqual(Set(store.loadAll().map(\.id)), ["a", "b"])
    }

    func testFirstLaunchWritesTheDemosOnceThenLoadsThem() {
        let first = EditorViewModel.launch(store: store)
        XCTAssertEqual(first.projects.count, 3)
        XCTAssertTrue(first.projects.allSatisfy(\.takes.isEmpty))   // demo drafts only, no mock takes
        let again = EditorViewModel.launch(store: store)
        XCTAssertEqual(Set(again.projects.map(\.id)), Set(first.projects.map(\.id)))
    }
}
