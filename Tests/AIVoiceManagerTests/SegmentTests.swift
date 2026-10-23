import XCTest
@testable import AIVoiceManagerApp

final class SegmentTests: XCTestCase {
    func testExpressionsGoInlineAndMutedScenesAreLeftOut() {
        XCTAssertEqual(segments(of: Fixtures.single), [
            Segment(speaker: .s1, style: "Friendly", text: "<breath> Hello <short pause>"),
            Segment(speaker: .s1, style: "Excited", text: "World")
        ])
    }

    func testTwoSpeakersKeepTheirOrder() {
        XCTAssertEqual(segments(of: Fixtures.two).map(\.speaker), [.s1, .s2])
        XCTAssertEqual(usedSpeakers(in: Fixtures.two), [.s1, .s2])
        XCTAssertEqual(usedSpeakers(in: Fixtures.single), [.s1])
    }

    func testRepeatedExpressionGoesToGeminiThatManyTimes() {
        var draft = Fixtures.two
        draft.items[2] = .expr(ExpressionScene(id: "c", tag: .sigh, times: 3))
        XCTAssertEqual(segments(of: draft).last?.text,
                       "Not too bad. Ready to hide some files from git? <sigh> <sigh> <sigh>")
    }

    func testEmptyTimelineStillHasASpeaker() {
        var draft = Fixtures.single
        draft.items = []
        XCTAssertEqual(segments(of: draft), [])
        XCTAssertEqual(usedSpeakers(in: draft), [.s1])
    }

    func testSplitTurnsKnownTagsIntoExpressionScenes() {
        let items = splitIntoItems("Hi <breath> there <unknown> end", speaker: .s2, style: "Sad")
        XCTAssertEqual(items.count, 5)
        guard case .expr(let breath) = items[1], case .script(let unknown) = items[3] else {
            return XCTFail("wrong kinds: \(items)")
        }
        XCTAssertEqual(breath.tag, .breath)
        XCTAssertEqual(unknown.text, "<unknown>")   // only catalog tags become expressions
        XCTAssertEqual(unknown.speaker, .s2)
    }

    func testEstimateMatchesThePrototype() {
        XCTAssertEqual(estimateSeconds("a"), 1)                           // never under a second
        XCTAssertEqual(estimateSeconds(String(repeating: "a", count: 30)), 2)
        XCTAssertEqual(estimateSeconds("aaaaaaaaaaaaaaa <breath>"), 16.0 / 15, accuracy: 0.0001)   // tags don't count
        // Thai: UTF-16 length like JS, so the combining vowel + tone mark in "น้ำ" count (3 units, 1 Character)
        XCTAssertEqual(estimateSeconds(String(repeating: "น้ำ", count: 13)), 3)
    }
}
