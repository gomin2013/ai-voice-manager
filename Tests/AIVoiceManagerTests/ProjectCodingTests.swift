import XCTest
@testable import AIVoiceManagerApp

final class ProjectCodingTests: XCTestCase {
    /// A draft as the prototype stores and exports it (`.avmproject.json`).
    private let prototypeJSON = """
        {"title": "B", "model": "gemini-3.8-flash-lite-tts",
         "speakers": {"S1": {"name": "Joe", "voice": "Puck"}, "S2": {"name": "Jane", "voice": "Kore"}},
         "items": [
           {"id": "a", "type": "script", "speaker": "S1", "style": "Cheerful and friendly",
            "text": "How's it going today Jane?", "muted": false},
           {"id": "b", "type": "script", "speaker": "S2", "style": "Calm and relaxed",
            "text": "Not too bad. Ready to hide some files from git?", "muted": false},
           {"id": "c", "type": "expr", "tag": "<sigh>", "muted": false}]}
        """

    func testPrototypeJSONDecodes() throws {
        let draft = try JSONDecoder().decode(ProjectDraft.self, from: Data(prototypeJSON.utf8))
        XCTAssertEqual(draft, Fixtures.two)
    }

    func testEncodesBackToThePrototypeShape() throws {
        let data = try JSONEncoder().encode(Fixtures.two)
        XCTAssertEqual(try Fixtures.json(data), try Fixtures.json(prototypeJSON))
    }

    /// Repeat ×N is `"times": N` and only written when > 1, so ×1 projects keep the prototype's exact shape.
    func testTimesIsWrittenOnlyWhenRepeated() throws {
        var draft = Fixtures.two
        draft.items[2] = .expr(ExpressionScene(id: "c", tag: .sigh, times: 3))
        let object = try Fixtures.json(JSONEncoder().encode(draft)) as? [String: Any]
        let items = try XCTUnwrap(object?["items"] as? [Any])
        XCTAssertEqual((items[2] as? [String: Any])?["times"] as? Int, 3)
        XCTAssertNil((items[1] as? [String: Any])?["times"])
        XCTAssertEqual(try JSONDecoder().decode(ProjectDraft.self, from: JSONEncoder().encode(draft)), draft)
    }

    func testSpeakersAreAnObjectNotAnArray() throws {
        let object = try XCTUnwrap(try Fixtures.json(JSONEncoder().encode(Fixtures.two)) as? [String: Any])
        XCTAssertNotNil(object["speakers"] as? [String: Any])
    }
}
