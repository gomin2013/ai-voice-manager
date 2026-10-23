import Foundation

/// `POST /v1beta/interactions` body (ADR-002) — must equal the prototype's `curl()` JSON (RequestBodyTests).
/// Built in Phase 2 so it's tested before Phase 3 sends it.
struct InteractionRequest: Encodable, Sendable {
    struct Annotation: Encodable, Sendable {
        let type = "speech_metadata"
        let style: String
        let speaker: String?   // only with two voices; nil is left out of the JSON
    }
    struct Part: Encodable, Sendable {
        let type = "text"
        let text: String
        let annotations: [Annotation]
    }
    struct Input: Encodable, Sendable {
        let type = "user_input"
        let content: [Part]
    }
    struct VoiceName: Encodable, Sendable { let voice: String }
    struct SpeakerVoice: Encodable, Sendable { let speaker: String; let voice: String }

    /// One voice → `[{voice}]`; two → `{mode: "conversational", speakers: [{speaker, voice}]}`.
    enum SpeechConfig: Encodable, Sendable {
        case single(String)
        case conversational([SpeakerVoice])

        private enum CodingKeys: String, CodingKey { case mode, speakers }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .single(let voice):
                var container = encoder.singleValueContainer()
                try container.encode([VoiceName(voice: voice)])
            case .conversational(let speakers):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("conversational", forKey: .mode)
                try container.encode(speakers, forKey: .speakers)
            }
        }
    }
    struct GenerationConfig: Encodable, Sendable {
        let speechConfig: SpeechConfig
        private enum CodingKeys: String, CodingKey { case speechConfig = "speech_config" }
    }

    let model: String
    let input: [Input]
    let responseFormat = ["type": "audio"]
    let generationConfig: GenerationConfig

    private enum CodingKeys: String, CodingKey {
        case model, input, responseFormat = "response_format", generationConfig = "generation_config"
    }

    init(draft: ProjectDraft) {
        let used = usedSpeakers(in: draft), multi = used.count > 1
        model = ModelCatalog.model(draft.model).id
        input = [Input(content: segments(of: draft).map { segment in
            let speaker = multi ? draft.speaker(segment.speaker).name : nil
            return Part(text: segment.text, annotations: [Annotation(style: segment.style, speaker: speaker)])
        })]
        generationConfig = GenerationConfig(speechConfig: multi
            ? .conversational(used.map { id in
                SpeakerVoice(speaker: draft.speaker(id).name, voice: draft.speaker(id).voice)
            })
            : .single(draft.speaker(used[0]).voice))
    }
}
