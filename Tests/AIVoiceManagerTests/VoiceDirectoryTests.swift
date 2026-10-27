import XCTest
@testable import AIVoiceManagerApp

/// Voice Library = Google's whole list (`GET /v1beta/voices`): the bundled snapshot, the 30 built-ins kept under
/// their old value, library voices stored as their id, pages followed by `next_page_token`, ids sent unchanged.
@MainActor
final class VoiceDirectoryTests: XCTestCase {
    private let noCache = URL(fileURLWithPath: "/nonexistent/voices.json")

    func testSnapshotHasTheLibraryAndRami() throws {
        let directory = VoiceDirectory(cache: noCache)
        XCTAssertGreaterThanOrEqual(directory.voices.count, 2000)
        let rami = try XCTUnwrap(directory.voice("en-us-rami"))
        XCTAssertEqual(rami.name, "Rami")
        XCTAssertEqual(rami.gender, .male)
        XCTAssertEqual(rami.pitch, "low")
        XCTAssertFalse(rami.isBuiltin)
    }

    func testBuiltinsKeepTheirOldValueAndWord() throws {
        let merged = VoiceDirectory.merge([
            VoiceDirectory.APIVoice(id: "puck", displayName: "Puck", gender: "male", pitch: "medium",
                                    languageCode: "en-US"),
            VoiceDirectory.APIVoice(id: "en-us-rami", displayName: "Rami", gender: "male", pitch: "low")
        ])
        let puck = try XCTUnwrap(merged.first { $0.value == "Puck" })
        XCTAssertTrue(puck.isBuiltin)
        XCTAssertEqual(puck.description, "Upbeat", "the built-in's own word, not Google's sentence")
        XCTAssertEqual(puck.language, "en-US")
        XCTAssertEqual(merged.filter(\.isBuiltin).count, 30, "a built-in missing from the list is still offered")
        XCTAssertNotNil(merged.first { $0.value == "en-us-rami" })
    }

    func testMissingFieldsDecodeAsEmpty() throws {
        let json = #"{"voices":[{"id":"ja-jp-x","display_name":"X"}]}"#
        let voices = try VoiceDirectory.decode(Data(json.utf8))
        XCTAssertEqual(voices, [VoiceDirectory.APIVoice(id: "ja-jp-x", displayName: "X")])
        XCTAssertEqual(VoiceDirectory.merge(voices).first { $0.value == "ja-jp-x" }?.gender, .neutral)
    }

    func testProjectFilesMayNameLibraryVoicesOnly() {
        XCTAssertTrue(VoiceCatalog.isVoiceValue("Puck"))
        XCTAssertTrue(VoiceCatalog.isVoiceValue("en-us-rami"))
        XCTAssertFalse(VoiceCatalog.isVoiceValue("../../etc/passwd"))
        XCTAssertFalse(VoiceCatalog.isVoiceValue("Rami Smith"))
        XCTAssertFalse(VoiceCatalog.isVoiceValue(""))
    }

    func testRequestSendsTheLibraryIdUnchanged() throws {
        var draft = Fixtures.single
        draft.speakers[.s1] = Speaker(name: "Rami", voice: "en-us-rami")
        let body = try JSONEncoder().encode(InteractionRequest(draft: draft))
        XCTAssertTrue(try XCTUnwrap(String(bytes: body, encoding: .utf8)).contains(#""voice":"en-us-rami""#))
    }

    func testListingFollowsEveryPage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PagedVoices.self]
        let voices = try await GeminiTTS.listVoices(key: "k", session: URLSession(configuration: config))
        XCTAssertEqual(voices.map(\.id), ["a-b", "c-d", "e-f"])
        XCTAssertEqual(PagedVoices.keys, ["k", "k", "k"], "the key goes in the header on every page")
    }
}

/// Three pages chained by `next_page_token`, like Google's (snake_case).
final class PagedVoices: URLProtocol {
    nonisolated(unsafe) static var keys: [String] = []
    private static let pages = [nil: (#"[{"id":"a-b","display_name":"A"}]"#, "p2"),
                                "p2": (#"[{"id":"c-d","display_name":"C"}]"#, "p3"),
                                "p3": (#"[{"id":"e-f","display_name":"E"}]"#, "")]

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.keys.append(request.value(forHTTPHeaderField: "x-goog-api-key") ?? "")
        let token = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "pageToken" }?.value
        let (voices, next) = Self.pages[token] ?? ("[]", "")
        let body = Data(#"{"voices":\#(voices),"next_page_token":"\#(next)"}"#.utf8)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                                              headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
