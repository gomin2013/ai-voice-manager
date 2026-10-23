import Foundation

/// Gemini allows two voices per request, so a project has exactly two speakers (ADR-006).
enum SpeakerID: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case s1 = "S1", s2 = "S2"

    var other: SpeakerID { self == .s1 ? .s2 : .s1 }
}

struct Speaker: Codable, Hashable, Sendable {
    var name: String
    var voice: String   // ∈ VoiceCatalog
}

struct ScriptScene: Codable, Hashable, Sendable {
    var id: String
    var speaker: SpeakerID
    var style: String
    var text: String
    var muted: Bool

    init(id: String = newSceneID(), speaker: SpeakerID = .s1, style: String = "Friendly", text: String = "",
         muted: Bool = false) {
        self.id = id
        self.speaker = speaker
        self.style = style
        self.text = text
        self.muted = muted
    }
}

struct ExpressionScene: Codable, Hashable, Sendable {
    var id: String
    var tag: ExpressionTag
    var muted: Bool

    init(id: String = newSceneID(), tag: ExpressionTag, muted: Bool = false) {
        self.id = id
        self.tag = tag
        self.muted = muted
    }
}

/// One row of the Script Timeline. Not called `Scene`: that would shadow `SwiftUI.Scene` in this module.
/// JSON = the prototype's `{ "type": "script" | "expr", … }`, so exported projects open in both.
enum TimelineItem: Codable, Hashable, Sendable, Identifiable {
    case script(ScriptScene)
    case expr(ExpressionScene)

    var id: String {
        switch self {
        case .script(let scene): scene.id
        case .expr(let scene): scene.id
        }
    }

    var isMuted: Bool {
        get {
            switch self {
            case .script(let scene): scene.muted
            case .expr(let scene): scene.muted
            }
        }
        set {
            switch self {
            case .script(var scene): scene.muted = newValue; self = .script(scene)
            case .expr(var scene): scene.muted = newValue; self = .expr(scene)
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
        self = type == "expr" ? .expr(try ExpressionScene(from: decoder)) : .script(try ScriptScene(from: decoder))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .script(let scene):
            try container.encode("script", forKey: .type)
            try scene.encode(to: encoder)
        case .expr(let scene):
            try container.encode("expr", forKey: .type)
            try scene.encode(to: encoder)
        }
    }
}

/// What History snapshots and Export writes.
struct ProjectDraft: Codable, Hashable, Sendable {
    var title: String
    var model: String   // ModelCatalog id
    var speakers: [SpeakerID: Speaker]
    var items: [TimelineItem]

    func speaker(_ id: SpeakerID) -> Speaker {
        speakers[id] ?? Speaker(name: id.rawValue, voice: VoiceCatalog.all[0].name)
    }

    mutating func setVoice(_ voice: String, for id: SpeakerID) {
        var updated = speaker(id)
        updated.voice = voice
        speakers[id] = updated
    }
}

struct Take: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let created: Date
    let duration: Double
    let draft: ProjectDraft
    let mock: Bool
}

struct Project: Hashable, Sendable, Identifiable {
    let id: String
    var opened: Date
    var draft: ProjectDraft
    var takes: [Take]
    var selection: String?
}

/// Fresh ids for new and imported scenes (the prototype's `newIid`).
func newSceneID() -> String { UUID().uuidString }
