import Foundation

/// Gemini TTS over the Interactions API (ADR-002): the user's key in a header, `InteractionRequest` in, a base64 WAV
/// (24 kHz mono 16-bit, with its RIFF header) out. Request / decode / error mapping are pure and tested; only
/// `generate` and `testKey` touch the network.
enum GeminiTTS {
    static let base = URL(string: "https://generativelanguage.googleapis.com/v1beta/")!

    /// What went wrong, in the user's terms (`message` is Google's own `error.message` when it sent one).
    enum Failure: Error, Equatable {
        case badKey(String)       // 401 / 403: wrong key, API not enabled, billing needed
        case quota(String)        // 429: free-tier limit
        case badRequest(String)   // 400: text too long, language the model can't read …
        case server(Int, String)  // 5xx and anything else
        case offline
        case noAudio              // 200 without an audio block

        @MainActor var text: String {
            switch self {
            case .badKey(let message): localized("errKey") + Self.detail(message)
            case .quota(let message): localized("errQuota") + Self.detail(message)
            case .badRequest(let message): localized("errRequest") + Self.detail(message)
            case .server(let status, let message): localized("errServer", "\(status)") + Self.detail(message)
            case .offline: localized("testOffline")
            case .noAudio: localized("errNoAudio")
            }
        }

        private static func detail(_ message: String) -> String { message.isEmpty ? "" : " — " + message }
    }

    /// The key goes in `x-goog-api-key`, never in the URL, so it can't end up in a log or a take.
    static func request(_ path: String, key: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: path, relativeTo: base)!.absoluteURL)
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 120   // a long take takes a while; there's no progress in unary mode
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// `steps[type == model_output].content[type == audio]`, the last one, base64 → WAV bytes (the docs' jq filter).
    static func audio(from json: Data) throws -> Data {
        struct Response: Decodable {
            struct Step: Decodable { let type: String; let content: [Block]? }
            struct Block: Decodable { let type: String; let data: String? }
            let steps: [Step]?
        }
        let response = try? JSONDecoder().decode(Response.self, from: json)
        let block = response?.steps?
            .filter { $0.type == "model_output" }
            .flatMap { $0.content ?? [] }
            .last { $0.type == "audio" && $0.data != nil }
        guard let base64 = block?.data, let wav = Data(base64Encoded: base64), !wav.isEmpty else {
            throw Failure.noAudio
        }
        return wav
    }

    /// Google's error body is `{"error": {"code", "message", "status", "details": [{"reason"}]}}`; the message is
    /// shown as it is. A wrong key is **400** with reason `API_KEY_INVALID` (checked 2026-10-23), not 401 / 403.
    /// `/interactions` wraps it in an array (`[{"error": …}]`), `/models` doesn't.
    static func failure(status: Int, body: Data) -> Failure {
        struct Envelope: Decodable {
            struct Inner: Decodable { let message: String?; let details: [Detail]? }
            struct Detail: Decodable { let reason: String? }
            let error: Inner?
        }
        let decoder = JSONDecoder()
        let error = ((try? decoder.decode(Envelope.self, from: body))
            ?? (try? decoder.decode([Envelope].self, from: body))?.first)?.error
        let message = error?.message ?? ""
        if error?.details?.contains(where: { $0.reason == "API_KEY_INVALID" }) == true { return .badKey(message) }
        return switch status {
        case 400: .badRequest(message)
        case 401, 403: .badKey(message)
        case 429: .quota(message)
        default: .server(status, message)
        }
    }

    /// The whole draft (or one scene's draft) → WAV bytes.
    static func generate(_ draft: ProjectDraft, key: String, session: URLSession = .shared) async throws -> Data {
        let body = try JSONEncoder().encode(InteractionRequest(draft: draft))
        return try await audio(from: send(request("interactions", key: key, body: body), session: session))
    }

    /// AI Providers › Test connection: list one model with the key — 200 means Google accepted it.
    static func testKey(_ key: String, session: URLSession = .shared) async throws {
        _ = try await send(request("models?pageSize=1", key: key), session: session)
    }

    private static func send(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw Failure.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw failure(status: status, body: data) }
        return data
    }
}
