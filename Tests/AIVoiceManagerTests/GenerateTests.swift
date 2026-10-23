import XCTest
@testable import AIVoiceManagerApp

/// Generate and scene preview against a fake Google (URLProtocol), writing takes into a temporary store.
@MainActor
final class GenerateTests: XCTestCase {
    private var store: ProjectStore!
    private var vm: EditorViewModel!

    override func setUp() async throws {
        LanguageService.shared.current = .english
        store = ProjectStore(root: FileManager.default.temporaryDirectory
            .appending(path: "avm-tests-\(UUID().uuidString)", directoryHint: .isDirectory))
        let project = Project(id: "p", opened: .now, draft: Fixtures.two, takes: [], selection: nil)
        let other = Project(id: "q", opened: .distantPast, draft: Fixtures.single, takes: [], selection: nil)
        for saved in [project, other] { try store.save(saved) }   // as the app does on first launch / New Project
        vm = EditorViewModel(projects: [project, other], hasGeminiKey: true, store: store)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeGoogle.self]
        vm.session = URLSession(configuration: config)
        vm.loadKey = { "AIza-test" }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: store.root)
        FakeGoogle.reply = nil
    }

    private func answer(wavSeconds: Double) {
        let audio = WAVTests.wav(seconds: wavSeconds).base64EncodedString()
        let json = #"{"steps":[{"type":"model_output","content":[{"type":"audio","data":"\#(audio)"}]}]}"#
        FakeGoogle.reply = (200, Data(json.utf8))
    }

    func testATakeIsAWavAndAJsonInItsOwnFolder() async throws {
        answer(wavSeconds: 2)
        await vm.generate()

        let take = try XCTUnwrap(vm.project.takes.first)
        XCTAssertFalse(take.mock)
        XCTAssertEqual(take.duration, 2, accuracy: 0.001)               // from the WAV, not the estimate
        XCTAssertEqual(take.draft, Fixtures.two)
        XCTAssertNotNil(vm.audio(of: take))
        XCTAssertEqual(store.loadAll().first?.takes.map(\.id), [take.id])  // take.json reads back
        XCTAssertEqual(FakeGoogle.lastKey, "AIza-test")
        XCTAssertEqual(vm.notice?.text, "Saved to Results")
    }

    func testAFailureLeavesNoTakeAndSaysWhatToDo() async {
        FakeGoogle.reply = (429, Data(#"[{"error":{"code":429,"message":"Quota exceeded"}}]"#.utf8))
        await vm.generate()

        XCTAssertTrue(vm.project.takes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.folder(of: "p").appending(path: "Takes").path))
        XCTAssertTrue(vm.notice?.text.hasPrefix("Free-tier limit reached") == true)
    }

    func testNoKeyAsksForOneInsteadOfCallingGoogle() async {
        vm.loadKey = { nil }
        FakeGoogle.reply = nil
        await vm.generate()
        XCTAssertFalse(vm.hasGeminiKey)
        XCTAssertTrue(vm.project.takes.isEmpty)
        XCTAssertEqual(vm.notice?.text, "Connect Google (Gemini API key) in AI Providers first.")
    }

    func testTheTakeGoesToTheProjectThatWasGeneratedEvenAfterASwitch() async throws {
        answer(wavSeconds: 1)
        let task = Task { await vm.generate() }
        for _ in 0..<10_000 where !vm.isGenerating { await Task.yield() }   // bounded: never spins forever
        XCTAssertTrue(vm.isGenerating)
        vm.switchProject(to: "q")
        await task.value
        XCTAssertEqual(vm.projects.first { $0.id == "p" }?.takes.count, 1)
        XCTAssertEqual(vm.project.takes.count, 0)
        XCTAssertEqual(store.loadAll().first { $0.id == "p" }?.takes.count, 1)
    }

    func testDeletedTakeGoesToTheTrashAndUndoBringsItBack() async throws {
        answer(wavSeconds: 1)
        await vm.generate()
        let take = try XCTUnwrap(vm.project.takes.first)

        vm.deleteTake(take.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.takeFolder(take.id, of: "p").path))
        try XCTUnwrap(vm.notice?.undo)()
        XCTAssertNotNil(vm.audio(of: take))
        XCTAssertEqual(vm.project.takes.map(\.id), [take.id])
    }

    func testScenePreviewIsReadyUntilTheSceneChanges() async throws {
        answer(wavSeconds: 1)
        guard case .script(let scene) = vm.draft.items[0] else { return XCTFail("not a script") }
        await vm.generatePreview(of: scene)

        XCTAssertEqual(try XCTUnwrap(vm.readyPreview(of: scene)).duration, 1, accuracy: 0.001)
        vm.setText("Something else", of: scene.id)
        guard case .script(let edited) = vm.draft.items[0] else { return XCTFail("not a script") }
        XCTAssertNil(vm.readyPreview(of: edited))   // stale after an edit
        XCTAssertTrue(vm.project.takes.isEmpty)     // a preview is never a take
    }
}

/// Answers every request with `reply` and remembers the key it was sent.
final class FakeGoogle: URLProtocol {
    nonisolated(unsafe) static var reply: (status: Int, body: Data)?
    nonisolated(unsafe) static var lastKey: String?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastKey = request.value(forHTTPHeaderField: "x-goog-api-key")
        guard let (status, body) = Self.reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
