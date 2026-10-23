import XCTest
@testable import AIVoiceManagerApp

@MainActor
final class OllamaTests: XCTestCase {
    private var vm: EditorViewModel!

    override func setUp() async throws {
        LanguageService.shared.current = .english
        let project = Project(id: "p", opened: .now, draft: Fixtures.two, takes: [], selection: nil)
        vm = EditorViewModel(projects: [project], hasGeminiKey: false)
    }

    private var labels: [String] { vm.history.steps.map(\.label) }

    func testChatRequestIsOllamasShape() throws {
        let messages: [OllamaClient.Message] = [.init(role: .system, content: "S"), .init(role: .user, content: "U")]
        let request = OllamaClient.chatRequest(model: "qwen3.8:latest", messages: messages, stream: true)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/chat")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "qwen3.8:latest")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["think"] as? Bool, false)
        let sent = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(sent, [["role": "system", "content": "S"], ["role": "user", "content": "U"]])
    }

    func testStreamLinesBecomePieces() {
        XCTAssertEqual(OllamaClient.piece(of: #"{"message":{"role":"assistant","content":"สวัส"},"done":false}"#), "สวัส")
        XCTAssertEqual(OllamaClient.piece(of: #"{"done":true,"total_duration":1}"#), "")
        XCTAssertNil(OllamaClient.piece(of: "not json"))
    }

    func testPolishReplacesTheSceneAsOneStep() async {
        vm.askOllama = { _, _ in "  How is your day going, Jane?  " }
        await vm.rewrite(.polish, sceneID: "a", model: "m")
        guard case .script(let scene) = vm.draft.items[0] else { return XCTFail("not a script") }
        XCTAssertEqual(scene.text, "How is your day going, Jane?")
        XCTAssertEqual(scene.id, "a")                       // selection stays on it
        XCTAssertEqual(labels.last, "✦ Polish")
        XCTAssertNil(vm.aiBusy)
    }

    func testTagsInTheAnswerBecomeExpressionScenes() async {
        vm.toggleMute("a")
        vm.askOllama = { _, _ in "How's it going <breath> today Jane?" }
        await vm.rewrite(.pauses, sceneID: "a", model: "m")
        XCTAssertEqual(vm.draft.items.count, Fixtures.two.items.count + 2)
        guard case .script(let first) = vm.draft.items[0], case .expr(let breath) = vm.draft.items[1] else {
            return XCTFail("wrong kinds: \(vm.draft.items)")
        }
        XCTAssertEqual(first.id, "a")
        XCTAssertEqual(breath.tag, .breath)
        XCTAssertTrue(vm.draft.items[0...2].allSatisfy(\.isMuted))   // the scene's mute carries over
        XCTAssertEqual(labels.last, "✦ Add pauses")
    }

    func testAnEditWhileOllamaThinksWins() async {
        vm.askOllama = { [vm] _, _ in
            await MainActor.run { vm?.setText("Typed meanwhile", of: "a") }
            return "Ollama's version"
        }
        await vm.rewrite(.polish, sceneID: "a", model: "m")
        guard case .script(let scene) = vm.draft.items[0] else { return XCTFail("not a script") }
        XCTAssertEqual(scene.text, "Typed meanwhile")
    }

    func testOllamaDownSaysSoAndChangesNothing() async {
        vm.askOllama = { _, _ in throw URLError(.cannotConnectToHost) }
        await vm.rewrite(.polish, sceneID: "a", model: "m")
        XCTAssertEqual(vm.draft, Fixtures.two)
        XCTAssertEqual(vm.notice?.text, "Ollama didn’t answer — check it’s still running, then try again.")
    }

    func testAgentKnowsTheProjectSceneByScene() {
        let context = vm.agentContext
        XCTAssertTrue(context.contains(#"Current project "B""#))
        XCTAssertTrue(context.contains("1. [Joe · Cheerful and friendly] How's it going today Jane?"))
        XCTAssertTrue(context.contains("3. <sigh>"))
    }
}
