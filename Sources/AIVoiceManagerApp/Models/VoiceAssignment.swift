import Foundation

enum VoiceAssignment: Equatable, Sendable {
    case unchanged
    case assigned
    /// Both speakers are taken by other scenes: the message names the two voices in use.
    case refused(inUse: [String])
}

/// Give a Script scene a voice under the two-voice limit (ADR-006, the prototype's `setSceneVoice`): join the speaker
/// that already has this voice, or take over a speaker nobody else uses; with two other voices in use, refuse.
@discardableResult
func assignVoice(_ voice: String, to sceneID: String, in draft: inout ProjectDraft) -> VoiceAssignment {
    guard let index = draft.items.firstIndex(where: { $0.id == sceneID }),
          case .script(var scene) = draft.items[index] else { return .unchanged }
    let own = scene.speaker, other = own.other
    func usedByOthers(_ speaker: SpeakerID) -> Bool {
        draft.items.contains { item in
            if case .script(let line) = item { line.id != sceneID && line.speaker == speaker } else { false }
        }
    }
    if draft.speaker(own).voice == voice { return .unchanged }
    if draft.speaker(other).voice == voice && usedByOthers(other) {
        scene.speaker = other
    } else if !usedByOthers(own) {
        draft.setVoice(voice, for: own)
    } else if !usedByOthers(other) {
        draft.setVoice(voice, for: other)
        scene.speaker = other
    } else {
        return .refused(inUse: [draft.speaker(.s1).voice, draft.speaker(.s2).voice])
    }
    draft.items[index] = .script(scene)
    return .assigned
}
