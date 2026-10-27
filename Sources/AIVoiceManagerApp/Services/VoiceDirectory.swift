import Foundation
import Observation

/// Every Gemini TTS voice (Google's library — 2,089 on 2026-10-27, the same as AI Studio): the 30 built-ins keep their
/// portraits and their stored name, every other voice is stored as its API id. Starts from the snapshot in the app
/// (`Resources/voices.json`), then a newer copy in Application Support; `refresh` lists them again with the Gemini key
/// (`GET /v1beta/voices` — free, no audio). No key or offline → still the snapshot.
@MainActor
@Observable
final class VoiceDirectory {
    static let shared = VoiceDirectory()

    private(set) var voices: [Voice]
    private(set) var isRefreshing = false
    @ObservationIgnored private var byValue: [String: Voice] = [:]

    /// The cached copy, refreshed at most once a week on launch.
    nonisolated static var cacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "AI Voice Manager/voices.json")
    }

    init(snapshot: Data? = VoiceDirectory.bundledSnapshot(), cache: URL = VoiceDirectory.cacheURL) {
        let data = (try? Data(contentsOf: cache)) ?? snapshot
        voices = data.flatMap { try? Self.decode($0) }.map(Self.merge) ?? VoiceCatalog.all
        index()
    }

    func voice(_ value: String) -> Voice? { byValue[value] }

    /// "Rami" for `en-us-rami`; the value itself for a voice the library doesn't know.
    func name(_ value: String) -> String { byValue[value]?.name ?? value }

    /// Lists the library with the key and caches it; a failed call keeps what we have.
    func refresh(key: String, session: URLSession = .shared) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        guard let listed = try? await GeminiTTS.listVoices(key: key, session: session), !listed.isEmpty else { return }
        voices = Self.merge(listed)
        index()
        let file = Snapshot(source: "GET /v1beta/voices", fetched: Date.now.formatted(.iso8601), voices: listed)
        if let data = try? JSONEncoder().encode(file) {
            try? FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    /// Launch: refresh when there's a key and the cache is missing or older than a week.
    func refreshIfStale(key: String?) async {
        guard let key, !key.isEmpty else { return }
        let modified = (try? Self.cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        if let modified, modified.timeIntervalSinceNow > -7 * 24 * 3600 { return }
        await refresh(key: key)
    }

    private func index() {
        byValue = Dictionary(voices.map { ($0.value, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - JSON (pure, tested)

    /// One voice as `GET /v1beta/voices` and the snapshot write it (snake_case keys).
    struct APIVoice: Codable, Equatable, Sendable {
        let id: String
        let displayName: String
        var gender = "", pitch = "", languageCode = "", accent = "", persona = "", description = ""

        enum CodingKeys: String, CodingKey {
            case id, displayName = "display_name", gender, pitch, languageCode = "language_code"
            case accent, persona, description
        }

        init(id: String, displayName: String, gender: String = "", pitch: String = "", languageCode: String = "") {
            (self.id, self.displayName, self.gender, self.pitch, self.languageCode) =
                (id, displayName, gender, pitch, languageCode)
        }

        /// A field Google leaves out decodes as "" (synthesized Decodable would throw).
        init(from decoder: Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            func text(_ key: CodingKeys) -> String { (try? box.decodeIfPresent(String.self, forKey: key)) ?? "" }
            id = try box.decode(String.self, forKey: .id)
            displayName = text(.displayName)
            (gender, pitch, languageCode) = (text(.gender), text(.pitch), text(.languageCode))
            (accent, persona, description) = (text(.accent), text(.persona), text(.description))
        }
    }

    struct Snapshot: Codable, Sendable {
        var source: String?   // optional: only `voices` is required to read a file
        var fetched: String?
        let voices: [APIVoice]
    }

    nonisolated static func decode(_ data: Data) throws -> [APIVoice] {
        try JSONDecoder().decode(Snapshot.self, from: data).voices
    }

    /// Built-ins first (old value, name, one-word description, portrait), then every other library voice.
    nonisolated static func merge(_ listed: [APIVoice]) -> [Voice] {
        let builtins = Dictionary(uniqueKeysWithValues: VoiceCatalog.all.map { ($0.value.lowercased(), $0) })
        let library = listed.map { api -> Voice in
            let builtin = builtins[api.id]
            return Voice(value: builtin?.value ?? api.id, name: builtin?.name ?? api.displayName,
                         description: builtin?.description ?? api.description,
                         gender: Gender(rawValue: api.gender) ?? builtin?.gender ?? .neutral,
                         pitch: api.pitch, language: api.languageCode, accent: api.accent, persona: api.persona,
                         isBuiltin: builtin != nil)
        }
        // The 30 with portraits first, in their old order (what v1 users know), then the library A–Z
        let first = VoiceCatalog.all.map { builtin in library.first { $0.value == builtin.value } ?? builtin }
        return first + library.filter { !$0.isBuiltin }
    }

    nonisolated static func bundledSnapshot() -> Data? {
        let bundle = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        return bundle.url(forResource: "voices", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }
}
