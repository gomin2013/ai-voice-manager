import Foundation
@testable import AIVoiceManagerApp

/// The same two drafts were fed to the prototype's `curl()` (2026-10-23) to get the expected request bodies.
enum Fixtures {
    /// One voice; a leading expression, an inline one, a muted line and a muted trailing expression.
    static let single = ProjectDraft(
        title: "A", model: "gemini-3.8-flash-tts",
        speakers: [.s1: Speaker(name: "Rami", voice: "Sulafat"), .s2: Speaker(name: "Mali", voice: "Kore")],
        items: [
            .expr(ExpressionScene(id: "a", tag: .breath)),
            .script(ScriptScene(id: "b", speaker: .s1, style: "Friendly", text: "Hello")),
            .expr(ExpressionScene(id: "c", tag: .shortPause)),
            .script(ScriptScene(id: "d", speaker: .s1, style: "Friendly", text: "muted line", muted: true)),
            .script(ScriptScene(id: "e", speaker: .s1, style: "Excited", text: "World")),
            .expr(ExpressionScene(id: "f", tag: .laugh, muted: true))
        ])

    /// Two voices, a trailing expression.
    static let two = ProjectDraft(
        title: "B", model: "gemini-3.8-flash-lite-tts",
        speakers: [.s1: Speaker(name: "Joe", voice: "Puck"), .s2: Speaker(name: "Jane", voice: "Kore")],
        items: [
            .script(ScriptScene(id: "a", speaker: .s1, style: "Cheerful and friendly",
                                text: "How's it going today Jane?")),
            .script(ScriptScene(id: "b", speaker: .s2, style: "Calm and relaxed",
                                text: "Not too bad. Ready to hide some files from git?")),
            .expr(ExpressionScene(id: "c", tag: .sigh))
        ])

    /// Parsed JSON, so comparisons ignore key order and whitespace.
    static func json(_ data: Data) throws -> NSObject {
        guard let object = try JSONSerialization.jsonObject(with: data) as? NSObject else {
            throw CocoaError(.coderReadCorrupt)
        }
        return object
    }
    static func json(_ string: String) throws -> NSObject { try json(Data(string.utf8)) }
}
