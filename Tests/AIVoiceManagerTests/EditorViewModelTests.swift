import XCTest
@testable import AIVoiceManagerApp

@MainActor
final class EditorViewModelTests: XCTestCase {
    private var vm: EditorViewModel!

    override func setUp() async throws {
        LanguageService.shared.current = .english   // labels are checked in English
        let project = Project(id: "p", opened: .now, draft: Fixtures.two, takes: [], selection: nil)
        let other = Project(id: "q", opened: .distantPast, draft: Fixtures.single, takes: [], selection: nil)
        vm = EditorViewModel(projects: [project, other])
    }

    private var labels: [String] { vm.history.steps.map(\.label) }

    func testRenameTrimsAndRefusesEmpty() {
        XCTAssertFalse(vm.rename("   "))
        XCTAssertEqual(vm.draft.title, "B")
        XCTAssertTrue(vm.rename("  Intro  "))
        XCTAssertEqual(vm.draft.title, "Intro")
        XCTAssertEqual(labels, ["When Opened", "Renamed project"])
    }

    func testNewScriptGoesAfterSelectionWithTheLineAbovesVoiceAndStyle() {
        vm.select("b")
        vm.addScript()
        guard case .script(let added) = vm.items[2] else { return XCTFail("expected a script at 3") }
        XCTAssertEqual(added.speaker, .s2)
        XCTAssertEqual(added.style, "Calm and relaxed")
        XCTAssertEqual(vm.selectedItem.id, added.id)
    }

    func testRemoveKeepsOneSceneAndMovesSelection() {
        vm.select("b")
        vm.removeScene("b")
        XCTAssertEqual(vm.items.map(\.id), ["a", "c"])
        XCTAssertEqual(vm.selectedItem.id, "c")
        XCTAssertEqual(labels.last, "Deleted scene 2")
        vm.removeScene("a")
        vm.removeScene("c")
        XCTAssertEqual(vm.items.count, 1)
    }

    func testRepeatIsOneStepClampedAndSkippedWhenUnchanged() {
        vm.setTimes(3, of: "c")
        XCTAssertEqual(labels.last, "Sigh ×3")
        let steps = labels.count
        vm.setTimes(3, of: "c")
        XCTAssertEqual(labels.count, steps)            // same value: no step
        vm.setTimes(50, of: "c")
        guard case .expr(let scene) = vm.draft.items[2] else { return XCTFail("not an expression") }
        XCTAssertEqual(scene.times, 10)
    }

    func testMuteIsAStepAndLeavesTheSceneOutOfTheTake() {
        vm.toggleMute("b")
        XCTAssertEqual(labels.last, "Muted scene 2")
        XCTAssertEqual(segments(of: vm.draft).count, 1)
    }

    func testRestoreIsANewStepSoNothingIsLost() throws {
        vm.toggleMute("a")
        let opened = try XCTUnwrap(vm.history.steps.first)
        vm.restore(opened.id)
        XCTAssertEqual(vm.draft, Fixtures.two)
        XCTAssertEqual(vm.history.steps.count, 3)   // opened, muted, restored
    }

    func testThirdVoiceIsRefusedWithAMessage() {
        vm.select("a")
        vm.addScript()   // a second Joe line
        let before = vm.draft
        vm.useVoice("Zephyr")
        XCTAssertEqual(vm.draft, before)
        XCTAssertEqual(vm.notice?.text.contains("Puck"), true)
    }

    func testEachProjectKeepsItsOwnHistory() {
        vm.toggleMute("a")
        vm.switchProject(to: "q")
        XCTAssertEqual(labels, ["When Opened"])
        vm.switchProject(to: "p")
        XCTAssertEqual(labels.count, 2)
    }

    func testHistoryKeepsTheLastThirty() {
        for _ in 0..<40 { vm.toggleMute("a") }
        XCTAssertEqual(vm.history.steps.count, 30)
        XCTAssertEqual(vm.history.pinned.count, 1)   // When Opened never falls off
    }

    func testRestoreTakeGivesFreshIds() throws {
        let take = Take(id: "t", created: .now, duration: 9, draft: Fixtures.single, mock: true)
        vm.add(Fixtures.two, takes: [take])
        vm.restoreTake("t")
        XCTAssertEqual(segments(of: vm.draft), segments(of: Fixtures.single))
        XCTAssertTrue(Set(vm.items.map(\.id)).isDisjoint(with: Fixtures.single.items.map(\.id)))
        XCTAssertEqual(vm.draft.title, "B")
    }
}
