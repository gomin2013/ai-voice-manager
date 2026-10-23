import SwiftUI

/// AI Agent: chat with Ollama about the project (prototype `panel_agent`). The answer streams in as Ollama writes
/// it; Stop cancels. Ollama not running → the prototype's canned MOCK answer, still about this project.
/// The conversation is view state, kept while the app runs (ToolWindow keeps every panel mounted).
struct AgentPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @Environment(OllamaStatus.self) private var ollama
    @State private var messages: [Message] = []
    @State private var draftQuestion = ""
    @State private var reply: Task<Void, Never>?

    private struct Message: Identifiable {
        let id = UUID()
        let question: String
        var answer: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            status
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty { intro }
                        ForEach(messages) { message in
                            Text(message.question).padding(8)
                                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(message.answer.isEmpty ? AttributedString(localized("ai.thinking"))
                                                        : markdown(message.answer))
                                .foregroundStyle(message.answer.isEmpty ? .secondary : .primary)
                                .textSelection(.enabled)
                                .id(message.id)
                        }
                    }
                }
                .onChange(of: messages.last?.answer) { scroller.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            HStack {
                TextField(localized("ai.ask"), text: $draftQuestion).textFieldStyle(.roundedBorder).onSubmit(send)
                if reply != nil {
                    Button(localized("stop")) { reply?.cancel() }
                } else {
                    Button(localized("ai.send"), action: send)
                        .disabled(draftQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .font(.app(12.5))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var status: some View {
        HStack(spacing: 6) {
            Circle().fill(ollama.isRunning ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .frame(width: 7, height: 7)
            if ollama.isRunning {
                @Bindable var ollama = ollama
                Picker(localized("ai.model"), selection: $ollama.model) {
                    ForEach(ollama.models, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            } else {
                Text(localized("ai.offline")).font(.app(11)).foregroundStyle(.secondary)
            }
        }
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

    private func send() {
        let question = draftQuestion.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty, reply == nil else { return }
        draftQuestion = ""
        guard ollama.isRunning else {
            messages.append(Message(question: question, answer: localized("ai.mock") + "\n\n" + vm.agentMockReply))
            Task { await ollama.probe() }   // started since launch? the next question uses it
            return
        }
        // The project as it is now, then the last 4 exchanges (the prototype's last 8 turns)
        var turns: [OllamaClient.Message] = [.init(role: .system, content: vm.agentContext)]
        for message in messages.suffix(4) {
            turns += [.init(role: .user, content: message.question), .init(role: .assistant, content: message.answer)]
        }
        turns.append(.init(role: .user, content: question))
        messages.append(Message(question: question, answer: ""))
        let index = messages.count - 1, model = ollama.model
        reply = Task {
            do {
                for try await piece in OllamaClient.stream(model: model, messages: turns) {
                    messages[index].answer += piece
                }
            } catch where Task.isCancelled {   // Stop: keep what came so far (URLSession throws URLError here)
            } catch {
                messages[index].answer += (messages[index].answer.isEmpty ? "" : "\n\n") + localized("ollamaFailed")
            }
            reply = nil
        }
    }
}
