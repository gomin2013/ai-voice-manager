import Foundation
import Observation

/// Ollama on this Mac (ADR-003): a script helper, never a voice — AI Agent chat and the scene's Polish / Add pauses.
/// `http://localhost:11434`, no login (Info.plist allows local networking). Request building and the NDJSON stream
/// parsing are pure and tested; `models`, `complete` and `stream` touch the network.
enum OllamaClient {
    static let base = URL(string: "http://localhost:11434/")!

    struct Message: Codable, Equatable, Sendable {
        enum Role: String, Codable, Sendable { case system, user, assistant }
        let role: Role
        let content: String
    }

    /// `POST /api/chat`. `think: false`: qwen3.8 otherwise thinks for tens of seconds before a one-line rewrite.
    static func chatRequest(model: String, messages: [Message], stream: Bool) -> URLRequest {
        struct Body: Encodable { let model: String, messages: [Message], stream: Bool, think: Bool }
        var request = URLRequest(url: base.appending(path: "api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300   // a big local model on a small Mac is slow; the user can Stop
        let body = Body(model: model, messages: messages, stream: stream, think: false)
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    /// One NDJSON line of a streamed reply → its text piece (empty for the closing `"done": true` line).
    static func piece(of line: String) -> String? {
        struct Line: Decodable { struct Inner: Decodable { let content: String? }; let message: Inner? }
        guard let data = line.data(using: .utf8), let parsed = try? JSONDecoder().decode(Line.self, from: data)
        else { return nil }
        return parsed.message?.content ?? ""
    }

    /// `GET /api/tags` → installed model names. Throws when Ollama isn't running.
    static func models(session: URLSession = .shared) async throws -> [String] {
        struct Tags: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
        var request = URLRequest(url: base.appending(path: "api/tags"))
        request.timeoutInterval = 3
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(Tags.self, from: data).models.map(\.name)
    }

    /// The whole answer at once (Polish / Add pauses: short, and replaced in one go).
    static func complete(model: String, messages: [Message], session: URLSession = .shared) async throws -> String {
        var answer = ""
        for try await piece in stream(model: model, messages: messages, session: session) { answer += piece }
        return answer
    }

    /// The answer piece by piece as Ollama writes it (AI Agent: progress instead of a long silent wait).
    static func stream(model: String, messages: [Message],
                       session: URLSession = .shared) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: chatRequest(model: model, messages: messages,
                                                                                    stream: true))
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                    for try await line in bytes.lines {
                        if let piece = piece(of: line), !piece.isEmpty { continuation.yield(piece) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Is Ollama running, which models it has, and the one the user picked (qwen3.8 first, like the prototype).
@MainActor
@Observable
final class OllamaStatus {
    private(set) var models: [String] = []
    private(set) var isRunning = false
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "ollama.model") }
    }

    init() { model = UserDefaults.standard.string(forKey: "ollama.model") ?? "" }

    /// On launch and "Check again".
    func probe() async {
        models = (try? await OllamaClient.models()) ?? []
        isRunning = !models.isEmpty
        if !models.contains(model) { model = models.first { $0.hasPrefix("qwen3.8") } ?? models.first ?? "" }
    }

    /// "qwen3.8" for the ✦ label (the tag after `:` is noise there).
    var shortName: String { model.split(separator: ":").first.map(String.init) ?? model }
}
