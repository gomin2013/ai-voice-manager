import Foundation

/// Gemini TTS models with a free tier (ADR-007). Prices per 1M tokens, checked 2026-10-22 — the only place they live.
struct TTSModel: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let freeTier: Bool
    let readsThai: Bool?   // nil = not known yet
    let inUSD: Double
    let outUSD: Double
}

enum ModelCatalog {
    static let all: [TTSModel] = [
        TTSModel(id: "gemini-3.8-flash-tts", name: "Gemini 3.8 Flash TTS",
                 freeTier: true, readsThai: true, inUSD: 0.5, outUSD: 9),
        TTSModel(id: "gemini-3.8-flash-lite-tts", name: "Gemini 3.8 Flash-Lite TTS",
                 freeTier: true, readsThai: false, inUSD: 0.5, outUSD: 6),
        TTSModel(id: "gemini-3.1-flash-tts-preview", name: "Gemini 3.1 Flash TTS (Preview)",
                 freeTier: true, readsThai: nil, inUSD: 1, outUSD: 20)
    ]
    static var standard: TTSModel { all[0] }

    static func model(_ id: String) -> TTSModel { all.first { $0.id == id } ?? standard }

    // ponytail: rough estimate, verify against real usageMetadata in Phase 3
    static let audioTokensPerSecond = 25.0

    /// Estimated USD for one take of `draft` (the prototype's `costUSD`).
    static func costUSD(of draft: ProjectDraft) -> Double {
        let text = plainText(of: draft), model = model(draft.model)
        let audio = estimateSeconds(text) * audioTokensPerSecond * model.outUSD
        return (audio + Double(text.utf16.count) / 4 * model.inUSD) / 1e6
    }
}

enum Gender: String, Sendable { case female, male, neutral }

/// A Gemini TTS voice. `value` is what a project stores and the request sends: a built-in's name ("Puck", kept so v1
/// projects still work) or a library voice's API id ("en-us-rami"). `name` is what the user reads.
struct Voice: Hashable, Sendable, Identifiable {
    let value: String
    let name: String
    let description: String   // built-in: Google's one word; library: Google's sentence — not translated
    let gender: Gender
    var pitch = ""             // low · medium · high
    var language = ""          // BCP 47, e.g. en-US
    var accent = ""
    var persona = ""
    var isBuiltin = true
    var id: String { value }
}

/// The 30 voices AVM shipped with (portraits in Art/Voices). The whole library is `VoiceDirectory`.
enum VoiceCatalog {
    // Gender per voice: Google Cloud TTS "Chirp 3: HD" voice list (same 30 names), checked 2026-10-23 — 14 ♀, 16 ♂.
    private static let female: Set = ["Achernar", "Aoede", "Autonoe", "Callirrhoe", "Despina", "Erinome", "Gacrux",
                                      "Kore", "Laomedeia", "Leda", "Pulcherrima", "Sulafat", "Vindemiatrix", "Zephyr"]
    private static let list = """
        Zephyr Bright|Puck Upbeat|Charon Informative|Kore Firm|Fenrir Excitable|Leda Youthful|Orus Firm|Aoede Breezy|\
        Callirrhoe Easy-going|Autonoe Bright|Enceladus Breathy|Iapetus Clear|Umbriel Easy-going|Algieba Smooth|\
        Despina Smooth|Erinome Clear|Algenib Gravelly|Rasalgethi Informative|Laomedeia Upbeat|Achernar Soft|\
        Alnilam Firm|Schedar Even|Gacrux Mature|Pulcherrima Forward|Achird Friendly|Zubenelgenubi Casual|\
        Vindemiatrix Gentle|Sadachbia Lively|Sadaltager Knowledgeable|Sulafat Warm
        """
    static let all: [Voice] = list.split(separator: "|").map { pair in
        let parts = pair.split(separator: " ").map(String.init)
        return Voice(value: parts[0], name: parts[0], description: parts[1],
                     gender: female.contains(parts[0]) ? .female : .male)
    }

    static func contains(_ name: String) -> Bool { all.contains { $0.value == name } }

    /// What a project file may name as a voice: a built-in, or a library id such as `en-us-rami` (opened files are
    /// untrusted — anything else falls back to the first built-in).
    static func isVoiceValue(_ value: String) -> Bool {
        contains(value) || value.wholeMatch(of: /[a-z]{2,3}(-[a-z0-9]+){1,4}/) != nil
    }
}

/// Gemini TTS tags. In the timeline each one is its own Expression scene; in the request they go inline.
enum ExpressionTag: String, Codable, CaseIterable, Sendable {
    case breath = "<breath>", shortPause = "<short pause>", longPause = "<long pause>"
    case laugh = "<laugh>", sigh = "<sigh>", gasp = "<gasp>", cough = "<cough>"

    /// `breath`, `short-pause` … — image file name and the `ex.` / `exd.` string keys (same as the prototype).
    var key: String { String(rawValue.dropFirst().dropLast()).replacingOccurrences(of: " ", with: "-") }
}

/// The `style` annotation Gemini reads before a line. English on purpose (that's what the model gets); the
/// description is localized under `style.<slug>`. Any other text still works: the Style box accepts free text.
struct StylePreset: Hashable, Sendable, Identifiable {
    let name: String
    var id: String { name }
    var slug: String {
        name.lowercased().split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "-")
    }

    static let all: [StylePreset] = [
        "Friendly", "Cheerful and friendly", "Calm and warm", "Calm and relaxed", "Excited", "Energetic, upbeat ad",
        "Narrator, documentary", "News anchor", "Storyteller", "Whisper", "Serious", "Sad"
    ].map(StylePreset.init)

    static func preset(_ name: String) -> StylePreset? { all.first { $0.name == name } }
}

/// Google bills in US dollars; the local amount is a hint only (roadmap #3). One currency per family language.
enum CurrencyRates {
    // ponytail: fixed rates set by hand (a live rate = a network call for a hint); refresh them together with `date`.
    static let date = "2026-10-23"
    static let perUSD: [String: Double] = ["USD": 1, "THB": 33, "JPY": 150, "KRW": 1380, "VND": 25400, "IDR": 16000,
                                           "MYR": 4.4, "PHP": 58, "CNY": 7.2, "TWD": 32, "EUR": 0.92, "RUB": 95]
    private static let byLanguage = ["en": "USD", "th": "THB", "ja": "JPY", "ko": "KRW", "vi": "VND", "id": "IDR",
                                     "ms": "MYR", "tl": "PHP", "zh-Hans": "CNY", "zh-Hant": "TWD", "es": "EUR",
                                     "ru": "RUB"]

    /// "Match language" resolves here; an unknown language falls back to USD.
    static func currency(forLanguage language: String) -> String { byLanguage[language] ?? "USD" }
}
