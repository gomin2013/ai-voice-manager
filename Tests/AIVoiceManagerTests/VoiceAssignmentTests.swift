import XCTest
@testable import AIVoiceManagerApp

final class VoiceAssignmentTests: XCTestCase {
    private func speaker(of id: String, in draft: ProjectDraft) -> SpeakerID? {
        for case .script(let scene) in draft.items where scene.id == id { return scene.speaker }
        return nil
    }

    func testSameVoiceIsUnchanged() {
        var draft = Fixtures.two
        XCTAssertEqual(assignVoice("Puck", to: "a", in: &draft), .unchanged)
        XCTAssertEqual(draft, Fixtures.two)
    }

    func testJoinsTheSpeakerThatHasTheVoice() {
        var draft = Fixtures.two
        XCTAssertEqual(assignVoice("Kore", to: "a", in: &draft), .assigned)
        XCTAssertEqual(speaker(of: "a", in: draft), .s2)
        XCTAssertEqual(draft.speaker(.s1).voice, "Puck")   // nobody else's voice changed
    }

    func testOnlySceneOfASpeakerChangesItsVoice() {
        var draft = Fixtures.two
        XCTAssertEqual(assignVoice("Zephyr", to: "b", in: &draft), .assigned)
        XCTAssertEqual(draft.speaker(.s2).voice, "Zephyr")
        XCTAssertEqual(speaker(of: "b", in: draft), .s2)
    }

    func testTakesOverTheUnusedSpeaker() {
        var draft = Fixtures.single
        draft.items.append(.script(ScriptScene(id: "x", speaker: .s1, text: "second line")))
        XCTAssertEqual(assignVoice("Zephyr", to: "x", in: &draft), .assigned)
        XCTAssertEqual(speaker(of: "x", in: draft), .s2)
        XCTAssertEqual(draft.speaker(.s2).voice, "Zephyr")
        XCTAssertEqual(draft.speaker(.s1).voice, "Sulafat")
    }

    func testRefusesAThirdVoice() {
        var draft = Fixtures.two
        draft.items.append(.script(ScriptScene(id: "x", speaker: .s1, text: "Joe again")))
        let before = draft
        XCTAssertEqual(assignVoice("Zephyr", to: "x", in: &draft), .refused(inUse: ["Puck", "Kore"]))
        XCTAssertEqual(draft, before)   // never drops a voice silently
    }

    func testExpressionSceneIsIgnored() {
        var draft = Fixtures.two
        XCTAssertEqual(assignVoice("Zephyr", to: "c", in: &draft), .unchanged)
    }
}
