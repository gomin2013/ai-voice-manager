import XCTest
@testable import AIVoiceManagerApp

@MainActor
final class RewriteTests: XCTestCase {
    private static let ollama = AISettings(provider: .ollama, model: "m", apiKey: "")

    private var vm: EditorViewModel!

    override func setUp() async throws {
        LanguageService.shared.current = .english
        let project = Project(id: "p", opened: .now, draft: Fixtures.two, takes: [], selection: nil)
        vm = EditorViewModel(projects: [project], hasGeminiKey: false)
    }

    private var labels: [String] { vm.history.steps.map(\.label) }

    func testPolishReplacesTheSceneAsOneStep() async {
        vm.askAI = { _, _, _ in "  How is your day going, Jane?  " }
        await vm.rewrite(.polish, sceneID: "a", settings: Self.ollama)
        guard case .script(let scene) = vm.draft.items[0] else { return XCTFail("not a script") }
        XCTAssertEqual(scene.text, "How is your day going, Jane?")
        XCTAssertEqual(scene.id, "a")                       // selection stays on it
        XCTAssertEqual(labels.last, "✦ Polish")
        XCTAssertNil(vm.aiBusy)
    }

    func testTagsInTheAnswerBecomeExpressionScenes() async {
        vm.toggleMute("a")
        vm.askAI = { _, _, _ in "How's it going <breath> today Jane?" }
        await vm.rewrite(.pauses, sceneID: "a", settings: Self.ollama)
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
        vm.askAI = { [vm] _, _, _ in
            await MainActor.run { vm?.setText("Typed meanwhile", of: "a") }
            return "Ollama's version"
        }
        await vm.rewrite(.polish, sceneID: "a", settings: Self.ollama)
        guard case .script(let scene) = vm.draft.items[0] else { return XCTFail("not a script") }
        XCTAssertEqual(scene.text, "Typed meanwhile")
    }

    func testAgentDownSaysSoAndChangesNothing() async {
        vm.askAI = { _, _, _ in throw URLError(.cannotConnectToHost) }
        await vm.rewrite(.polish, sceneID: "a", settings: Self.ollama)
        XCTAssertEqual(vm.draft, Fixtures.two)
        XCTAssertEqual(vm.notice?.text, "The AI Agent didn’t answer — check AI Providers › AI Agent, then try again.")
    }

    func testAgentKnowsTheProjectSceneByScene() {
        let context = vm.agentContext
        XCTAssertTrue(context.contains(#"Current project "B""#))
        XCTAssertTrue(context.contains("1. [Joe · Cheerful and friendly] How's it going today Jane?"))
        XCTAssertTrue(context.contains("3. <sigh>"))
    }
}
