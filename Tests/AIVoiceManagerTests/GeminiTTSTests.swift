import XCTest
@testable import AIVoiceManagerApp

final class GeminiTTSTests: XCTestCase {
    private let wav = Data("RIFF....WAVEfmt ".utf8)

    private func response(_ steps: String) -> Data { Data(#"{"id":"x","steps":[\#(steps)]}"#.utf8) }

    func testAudioIsTheLastAudioBlockOfTheModelOutput() throws {
        let other = Data("old".utf8).base64EncodedString(), take = wav.base64EncodedString()
        let json = response("""
            {"type":"user_input","content":[{"type":"text","text":"hi"}]},
            {"type":"model_output","content":[{"type":"audio","mime_type":"audio/wav","data":"\(other)"},
                                              {"type":"text","text":"note"},
                                              {"type":"audio","mime_type":"audio/wav","data":"\(take)"}]}
            """)
        XCTAssertEqual(try GeminiTTS.audio(from: json), wav)
    }

    func testNoAudioBlockIsAFailureNotAnEmptyTake() {
        let onlyText = response(#"{"type":"model_output","content":[{"type":"text","text":"sorry"}]}"#)
        for body in [onlyText, Data("not json".utf8), response(""), Data(#"{"steps":[]}"#.utf8)] {
            XCTAssertThrowsError(try GeminiTTS.audio(from: body)) { XCTAssertEqual($0 as? GeminiTTS.Failure, .noAudio) }
        }
    }

    func testStatusCodesMapToWhatTheUserCanDo() {
        let body = Data(#"{"error":{"code":429,"message":"Quota exceeded","status":"RESOURCE_EXHAUSTED"}}"#.utf8)
        XCTAssertEqual(GeminiTTS.failure(status: 429, body: body), .quota("Quota exceeded"))
        XCTAssertEqual(GeminiTTS.failure(status: 400, body: body), .badRequest("Quota exceeded"))
        XCTAssertEqual(GeminiTTS.failure(status: 403, body: Data()), .badKey(""))
        XCTAssertEqual(GeminiTTS.failure(status: 401, body: Data("<html>".utf8)), .badKey(""))
        XCTAssertEqual(GeminiTTS.failure(status: 503, body: Data()), .server(503, ""))
    }

    /// Google's real answer to a wrong key (curl, 2026-10-23): 400, told apart only by the reason.
    func testWrongKeyIs400WithApiKeyInvalid() {
        let body = Data(#"""
            {"error":{"code":400,"message":"API key not valid. Please pass a valid API key.",
             "status":"INVALID_ARGUMENT",
             "details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"API_KEY_INVALID",
                         "domain":"googleapis.com","metadata":{"service":"generativelanguage.googleapis.com"}}]}}
            """#.utf8)
        let message = "API key not valid. Please pass a valid API key."
        XCTAssertEqual(GeminiTTS.failure(status: 400, body: body), .badKey(message))
        // /interactions sends the same error inside an array
        let wrapped = Data("[".utf8) + body + Data("]".utf8)
        XCTAssertEqual(GeminiTTS.failure(status: 400, body: wrapped), .badKey(message))
    }

    func testKeyTravelsInTheHeaderOnly() throws {
        let body = try JSONEncoder().encode(InteractionRequest(draft: Fixtures.two))
        let request = GeminiTTS.request("interactions", key: "AIza-secret", body: body)
        XCTAssertEqual(request.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/interactions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "AIza-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertFalse(String(bytes: request.httpBody ?? Data(), encoding: .utf8)?.contains("AIza") ?? true)

        let test = GeminiTTS.request("models?pageSize=1", key: "AIza-secret")
        XCTAssertEqual(test.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1")
        XCTAssertEqual(test.httpMethod, "GET")
    }
}
