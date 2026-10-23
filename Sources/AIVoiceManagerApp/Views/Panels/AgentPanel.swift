import SwiftUI

/// AI Agent — ponytail: Phase 2 mock (no network). Ollama + hosts-manager's ChatPanel / AIStreaming arrive with
/// OllamaClient in Phase 3; this keeps the prototype's offline look: intro, Try asking, canned MOCK answers.
struct AgentPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @State private var messages: [Message] = []

    private struct Message: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }
    @State private var draftQuestion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(.secondary).frame(width: 7, height: 7)
                Text(localized("ai.offline")).font(.app(11)).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty { intro }
                    ForEach(messages) { message in
                        Text(message.question).padding(8)
                            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(markdown(message.answer)).textSelection(.enabled)
                    }
                }
            }
            HStack {
                TextField(localized("ai.ask"), text: $draftQuestion).textFieldStyle(.roundedBorder).onSubmit(send)
                Button(localized("ai.send"), action: send)
                    .disabled(draftQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .font(.app(12.5))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦ " + localized("panel.agent")).font(.app(18, .bold))
            Text(localized("ai.intro")).foregroundStyle(.secondary)
            Text(localized("ai.try").uppercased())
                .font(.app(11, .semibold)).foregroundStyle(.secondary).padding(.top, 6)
            ForEach(["q.hook", "q.short", "q.pauses", "q.en", "q.style"], id: \.self) { key in
                Button { draftQuestion = localized(key); send() } label: {
                    HStack {
                        Text(localized(key))
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            }
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    /// The prototype's `mockReply`: names who says what, so the canned answer is still about this project.
    private func send() {
        let question = draftQuestion.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else { return }
        let lines = segments(of: vm.draft).map { "**\(vm.draft.speaker($0.speaker).name)**: " +
            $0.text.replacing(/<[^>]+>/, with: "").trimmingCharacters(in: .whitespaces) }
        let answer = localized("ai.mock") + "\n\n" + lines.joined(separator: "\n")
        messages.append(Message(question: question, answer: answer))
        draftQuestion = ""
    }
}
