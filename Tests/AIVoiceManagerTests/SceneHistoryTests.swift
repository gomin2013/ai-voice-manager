import XCTest
@testable import AIVoiceManagerApp

/// History › Scene: text edits become rows (with the text they started from), restoring one changes only that
/// scene, and History › Script keeps its own steps.
@MainActor
final class SceneHistoryTests: XCTestCase {
    private var vm: EditorViewModel!

    override func setUp() async throws {
        LanguageService.shared.current = .english
        let project = Project(id: "p", opened: .now, draft: Fixtures.two, takes: [], selection: nil)
        vm = EditorViewModel(projects: [project], hasGeminiKey: false)
    }

    private var texts: [String] { vm.sceneHistory.edits.map(\.text) }

    func testDeletingTextKeepsWhatItWas() {
        let scriptSteps = vm.history.steps.count
        vm.setText("How's it going", of: "a")
        vm.commitText(of: "a")
        XCTAssertEqual(texts, ["How's it going today Jane?", "How's it going"])
        XCTAssertEqual(vm.sceneHistory.edits.map(\.label), ["Scene 1 before editing", "Edited scene 1"])
        XCTAssertEqual(vm.history.steps.count, scriptSteps, "text edits live in History › Scene")

        vm.commitText(of: "a")   // nothing new typed: no row
        XCTAssertEqual(texts.count, 2)
    }

    func testRestoringChangesOnlyThatScene() throws {
        vm.setText("How's it going", of: "a")
        vm.commitText(of: "a")
        vm.setText("Not bad.", of: "b")
        vm.commitText(of: "b")
        let original = try XCTUnwrap(vm.sceneHistory.edits.first)

        vm.restoreSceneText(original.id)
        XCTAssertEqual(EditorViewModel.text(of: "a", in: vm.draft), "How's it going today Jane?")
        XCTAssertEqual(EditorViewModel.text(of: "b", in: vm.draft), "Not bad.", "other scenes untouched")
        XCTAssertEqual(vm.sceneHistory.edits.last?.label, "Restored “Scene 1 before editing”")
        XCTAssertNotNil(vm.sceneHistory.edit(original.id), "going back is a new row; nothing is lost")
    }

    func testKeepsTheLastThirty() {
        var history = SceneHistory()
        for index in 0..<40 {
            history.record(sceneID: "a", label: "\(index)", text: "\(index)", before: "x", beforeLabel: "before")
        }
        XCTAssertEqual(history.edits.count, SceneHistory.limit)
        XCTAssertEqual(history.edits.last?.text, "39")
        XCTAssertTrue(history.isCurrent(history.edits[29]))
        XCTAssertFalse(history.isCurrent(history.edits[28]))
    }
}
