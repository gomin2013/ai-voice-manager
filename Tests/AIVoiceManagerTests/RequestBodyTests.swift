import XCTest
@testable import AIVoiceManagerApp

/// Expected bodies = the prototype's `curl()` output for the same fixtures (run in the browser 2026-10-23).
final class RequestBodyTests: XCTestCase {
    func testSingleVoiceBody() throws {
        let expected = """
            {"model":"gemini-3.8-flash-tts","input":[{"type":"user_input","content":[\
            {"type":"text","text":"<breath> Hello <short pause>","annotations":[\
            {"type":"speech_metadata","style":"Friendly"}]},\
            {"type":"text","text":"World","annotations":[{"type":"speech_metadata","style":"Excited"}]}]}],\
            "response_format":{"type":"audio"},"generation_config":{"speech_config":[{"voice":"Sulafat"}]}}
            """
        let body = try JSONEncoder().encode(InteractionRequest(draft: Fixtures.single))
        XCTAssertEqual(try Fixtures.json(body), try Fixtures.json(expected))
    }

    func testConversationalBody() throws {
        let expected = """
            {"model":"gemini-3.8-flash-lite-tts","input":[{"type":"user_input","content":[\
            {"type":"text","text":"How's it going today Jane?","annotations":[{"type":"speech_metadata",\
            "style":"Cheerful and friendly","speaker":"Joe"}]},\
            {"type":"text","text":"Not too bad. Ready to hide some files from git? <sigh>","annotations":[\
            {"type":"speech_metadata","style":"Calm and relaxed","speaker":"Jane"}]}]}],\
            "response_format":{"type":"audio"},"generation_config":{"speech_config":{"mode":"conversational",\
            "speakers":[{"speaker":"Joe","voice":"Puck"},{"speaker":"Jane","voice":"Kore"}]}}}
            """
        let body = try JSONEncoder().encode(InteractionRequest(draft: Fixtures.two))
        XCTAssertEqual(try Fixtures.json(body), try Fixtures.json(expected))
    }
}
