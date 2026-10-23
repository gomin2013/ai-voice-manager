import XCTest
@testable import AIVoiceManagerApp

final class ImportCleaningTests: XCTestCase {
    private func load(_ json: String) -> ProjectDraft {
        clean(imported: try? JSONSerialization.jsonObject(with: Data(json.utf8)), fallbackTitle: "file.json")
    }

    func testRepeatIsClampedToOneThroughTen() {
        let draft = load("""
            {"items": [{"type": "expr", "tag": "<laugh>", "times": 99}, {"type": "expr", "tag": "<sigh>", "times": "x"},
                       {"type": "expr", "tag": "<cough>", "times": 4}, {"type": "expr", "tag": "<gasp>", "times": -2}]}
            """)
        XCTAssertEqual(draft.items.map { item -> Int in if case .expr(let scene) = item { scene.times } else { 0 } },
                       [10, 1, 4, 1])
    }

    func testUnknownVoiceModelSpeakerAndTagAreReplaced() {
        let draft = load("""
            {"title": "T", "model": "gpt-voice", "speakers": {"S1": {"name": "A", "voice": "Siri"}, "S9": {}},
             "items": [{"type": "script", "speaker": "S7", "style": "X", "text": "hi"},
                       {"type": "expr", "tag": "<scream>"}]}
            """)
        XCTAssertEqual(draft.model, ModelCatalog.standard.id)
        XCTAssertEqual(draft.speaker(.s1), Speaker(name: "A", voice: "Zephyr"))
        XCTAssertEqual(draft.speaker(.s2), Speaker(name: "Mali", voice: "Zephyr"))
        guard case .script(let line) = draft.items[0], case .expr(let tag) = draft.items[1] else {
            return XCTFail("wrong kinds: \(draft.items)")
        }
        XCTAssertEqual(line.speaker, .s1)
        XCTAssertEqual(tag.tag, .breath)
    }

    func testStringsAndCountsAreCapped() {
        let long = String(repeating: "x", count: 20_000)
        let items = Array(repeating: #"{"type": "expr", "tag": "<sigh>"}"#, count: 1200).joined(separator: ",")
        let draft = load("""
            {"title": "\(long)", "speakers": {"S1": {"name": "\(long)"}},
             "items": [{"type": "script", "text": "\(long)", "style": "\(long)"}, \(items)]}
            """)
        XCTAssertEqual(draft.title.count, 200)
        XCTAssertEqual(draft.speaker(.s1).name.count, 40)
        XCTAssertEqual(draft.items.count, 1000)
        guard case .script(let line) = draft.items[0] else { return XCTFail("first item should be a line") }
        XCTAssertEqual(line.text.count, 10_000)
        XCTAssertEqual(line.style.count, 200)
    }

    func testIdsAreFreshAndMarkupStaysText() {
        let draft = load(#"""
            {"items": [{"id": "x\" onclick=\"evil()", "type": "script", "text": "<script>alert(1)</script>"}]}
            """#)
        XCTAssertEqual(draft.title, "file.json")
        XCTAssertNotEqual(draft.items[0].id, #"x" onclick="evil()"#)
        guard case .script(let line) = draft.items[0] else { return XCTFail("should stay a line") }
        XCTAssertEqual(line.text, "<script>alert(1)</script>")   // kept as text, never interpreted
    }

    func testOldBlocksFormatIsSplitIntoScenes() {
        let draft = load(#"{"blocks": [{"speaker": "S2", "style": "Sad", "text": "One <breath> two"}]}"#)
        XCTAssertEqual(draft.items.count, 3)
        guard case .expr(let tag) = draft.items[1] else { return XCTFail("middle should be <breath>") }
        XCTAssertEqual(tag.tag, .breath)
    }

    func testJunkGivesOneEmptyScene() {
        for junk in ["[]", "42", #"{"items": "nope"}"#, "not json"] {
            let draft = load(junk)
            XCTAssertEqual(draft.items.count, 1, junk)
            XCTAssertEqual(draft.title, "file.json", junk)
        }
    }
}
