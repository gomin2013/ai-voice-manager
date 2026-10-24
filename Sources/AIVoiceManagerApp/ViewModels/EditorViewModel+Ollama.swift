import Foundation

/// The AI Agent (any provider in AI Providers › AI Agent): the scene's ✦ Polish / Add pauses, and what the chat
/// knows about the project.
extension EditorViewModel {
    enum Rewrite: Sendable {
        case polish, pauses

        /// The prototype's `OLLAMA_PROMPTS`.
        var prompt: String {
            switch self {
            case .polish:
                "Polish this voice-over script so it sounds natural when spoken. Keep the language and any <tags>."
            case .pauses:
                "Insert Gemini TTS tags <breath> and <short pause> where a voice actor would naturally pause. "
                    + "Change nothing else."
            }
        }

        var labelKey: String { self == .polish ? "oPolish" : "oTags" }
    }

    /// Rewrites this Script scene only; tags in the answer become Expression scenes where they were — one History
    /// step. If the scene is deleted or edited while the AI thinks, the answer is dropped (never clobbers typing).
    func rewrite(_ kind: Rewrite, sceneID: String, settings: AISettings) async {
        guard aiBusy == nil, case .script(let scene) = items.first(where: { $0.id == sceneID }),
              !scene.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        aiBusy = sceneID
        defer { aiBusy = nil }
        let answer: String
        do {
            let system = kind.prompt + " Reply with the script only."
            answer = try await askAI(settings, system, [ChatTurn(role: .user, text: scene.text)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            notice = Notice(text: localized("ollamaFailed"))
            return
        }
        guard let at = items.firstIndex(where: { $0.id == sceneID }), case .script(let now) = items[at],
              now.text == scene.text, !answer.isEmpty, answer != scene.text else { return }
        var parts = splitIntoItems(answer, speaker: scene.speaker, style: scene.style)
        guard let first = parts.firstIndex(where: { if case .script = $0 { true } else { false } }) else { return }
        for index in parts.indices { parts[index].isMuted = scene.muted }
        if case .script(var line) = parts[first] {   // keeps the selection on the rewritten scene
            line.id = sceneID
            parts[first] = .script(line)
        }
        draft.items.replaceSubrange(at...at, with: parts)
        record(localized("hist.ai", localized(kind.labelKey)))
    }

    /// The AI Agent's system prompt (prototype `aiContext`): the project scene by scene.
    var agentContext: String {
        let scenes = items.enumerated().map { index, item -> String in
            let muted = item.isMuted ? "(muted) " : ""
            return switch item {
            case .expr(let scene): "\(index + 1). \(muted)\(scene.text)"
            case .script(let scene):
                "\(index + 1). \(muted)[\(draft.speaker(scene.speaker).name) · \(scene.style)] \(scene.text)"
            }
        }
        return """
            You help write voice-over scripts for Gemini TTS. Answer briefly, in the script's language. Keep <tags> \
            like <breath>.
            You never change the project yourself: the user copies what they like. Current project \
            "\(draft.title)", scene by scene:
            """ + "\n" + scenes.joined(separator: "\n")
    }

    /// Offline answer (prototype `mockReply`): who says what, so it's still about this project.
    var agentMockReply: String {
        segments(of: draft).map {
            "**\(draft.speaker($0.speaker).name)**: " + $0.text.replacing(/<[^>]+>/, with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")
    }
}
