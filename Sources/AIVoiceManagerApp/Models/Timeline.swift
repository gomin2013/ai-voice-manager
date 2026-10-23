import Foundation

/// One `user_input` text part of the request: a Script scene with the expressions around it inlined as tags.
struct Segment: Hashable, Sendable {
    let speaker: SpeakerID
    let style: String
    let text: String
}

/// Timeline → what Gemini gets (the prototype's `segmentsOf`): one segment per Script scene, Expressions inline as
/// tags (a leading one goes before the first line), muted scenes left out.
func segments(of draft: ProjectDraft) -> [Segment] {
    var out: [Segment] = []
    var lead = ""
    for item in draft.items where !item.isMuted {
        switch item {
        case .expr(let scene):
            if let last = out.popLast() {
                let text = last.text + " " + scene.tag.rawValue
                out.append(Segment(speaker: last.speaker, style: last.style, text: text))
            } else {
                lead += scene.tag.rawValue + " "
            }
        case .script(let scene):
            out.append(Segment(speaker: scene.speaker, style: scene.style, text: lead + scene.text))
            lead = ""
        }
    }
    return out
}

func plainText(of draft: ProjectDraft) -> String { segments(of: draft).map(\.text).joined(separator: "\n") }

/// Speakers that actually speak, in order of first line; `[.s1]` for an empty timeline.
func usedSpeakers(in draft: ProjectDraft) -> [SpeakerID] {
    var seen: [SpeakerID] = []
    for segment in segments(of: draft) where !seen.contains(segment.speaker) { seen.append(segment.speaker) }
    return seen.isEmpty ? [.s1] : seen
}

func containsThai(_ text: String) -> Bool { text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) } }

/// Thai has no sentence punctuation, so estimate by characters.
/// ponytail: ~13 chars/s TH, ~15 EN; Phase 3 replaces it with the real WAV length.
/// UTF-16 count on purpose: matches the prototype's `length` (Thai vowels and tone marks are combining marks, so
/// `String.count` would come out shorter).
func estimateSeconds(_ text: String) -> Double {
    let spoken = text.replacing(/<[^>]+>/, with: "")
    return max(1, Double(spoken.utf16.count) / (containsThai(text) ? 13 : 15))
}

/// Text with inline `<tags>` → Script and Expression scenes (the prototype's `blocksToItems`): known tags become
/// Expression scenes, the rest is trimmed and kept as lines. Used for old `blocks` projects and Polish / Add pauses.
func splitIntoItems(_ text: String, speaker: SpeakerID, style: String) -> [TimelineItem] {
    var items: [TimelineItem] = []
    func addLine(_ part: Substring) {
        let line = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { items.append(.script(ScriptScene(speaker: speaker, style: style, text: line))) }
    }
    var rest = text[...]
    while let match = rest.firstMatch(of: /<[^>]+>/) {
        addLine(rest[..<match.range.lowerBound])
        if let tag = ExpressionTag(rawValue: String(match.output)) {
            items.append(.expr(ExpressionScene(tag: tag)))
        } else {
            addLine(match.output)   // an unknown <tag> stays text, like the prototype
        }
        rest = rest[match.range.upperBound...]
    }
    addLine(rest)
    return items
}
