import SwiftUI

/// AI Agent — Hosts Manager's ChatPanel + ChatIntro for this project: any of the five providers (AI Providers ›
/// AI Agent; the gear opens it), a step checklist (attached → waiting → thinking → writing), the model's thinking,
/// Markdown as it streams, Stop. The AI only answers; changes go through the editor. ToolWindow keeps every panel
/// mounted, so the conversation lives in @State while the app runs.
struct AgentPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @Environment(AgentSettings.self) private var agent
    @AppStorage("ui.leftPanel") private var leftPanel = LeftPanel.providers.rawValue
    @AppStorage("ui.providersTab") private var providersTab = "voices"

    /// Where the live reply is. The project is attached the moment the question is sent.
    enum Step: Int, Comparable {
        case attached, waiting, thinking, writing
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var turns: [ChatTurn] = []
    @State private var input = ""
    @State private var chatError: String?
    /// Non-nil while a reply streams (Stop cancels it).
    @State private var reply: Task<Void, Never>?
    @State private var step = Step.waiting
    @State private var startedAt = Date.now
    /// Finished turns whose thinking the user opened.
    @State private var openThinking: Set<Int> = []

    /// The start page's one-click questions and their icons (Hosts Manager's ChatIntro).
    static let quickQuestions = [("q.hook", "text.alignleft"), ("q.short", "timer"), ("q.pauses", "pause.circle"),
                                 ("q.en", "character.bubble"), ("q.style", "face.smiling")]

    private var isAsking: Bool { reply != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if turns.isEmpty { intro } else { transcript }
            inputRow
        }
        .font(.app(12.5))
        .task(id: agent.settings.provider.rawValue + agent.settings.apiKey) { await agent.loadModels() }
    }

    private var header: some View {
        HStack {
            modelMenu
            Spacer()
            Button(action: openSettings, label: { Image(systemName: "gearshape") })
                .buttonStyle(.borderless)
                .help(localized("settings.title"))
                .accessibilityLabel(localized("settings.title"))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    /// ⚙ / Set Up: AI Providers on the left, on its AI Agent tab (Hosts Manager opens a sheet; AVM has the panel).
    private func openSettings() {
        providersTab = "agent"
        leftPanel = LeftPanel.providers.rawValue
    }

    /// Current model; click to switch models of the same provider.
    private var modelMenu: some View {
        Menu {
            if agent.settings.provider.needsModel {
                ForEach(agent.models, id: \.self) { model in
                    Button(action: { agent.setModel(model) }, label: {
                        let name = AIService.modelLabel(model, provider: agent.settings.provider)
                        if model == agent.settings.model { Label(name, systemImage: "checkmark") } else { Text(name) }
                    })
                }
                if agent.models.isEmpty { Text(localized("settings.noModels")) }
                Divider()
            }
            Button(localized("settings.title") + "…", action: openSettings)
        } label: {
            Text(agent.label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(agent.isConfigured ? Color.primary : Color.orange)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(agent.settings.provider.displayName)
    }

    // MARK: - Start page (Hosts Manager's ChatIntro)

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.title).foregroundStyle(.tint).accessibilityHidden(true)
                    Text(localized("panel.agent")).font(.app(20, .bold))
                }
                Text(localized("ai.intro")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if agent.isConfigured {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("ai.try")).font(.app(13, .semibold)).padding(.bottom, 6)
                        ForEach(Self.quickQuestions, id: \.0) { key, icon in quickRow(key, icon: icon) }
                    }
                } else {
                    Button(localized("chat.setUp"), action: openSettings).glassButton(prominent: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    private func quickRow(_ key: String, icon: String) -> some View {
        Button { input = localized(key); send() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(.tint).frame(width: 18).accessibilityHidden(true)
                Text(localized(key)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(turns.enumerated()), id: \.offset) { index, turn in
                    if turn.role == .user { question(turn.text) } else { answer(turn, index: index) }
                }
                if let chatError {
                    Text(chatError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
                if !agent.isConfigured {
                    Button(localized("chat.setUp"), action: openSettings).buttonStyle(.link).font(.caption)
                }
            }
            .padding(10)
        }
        .defaultScrollAnchor(.bottom)
        .frame(maxHeight: .infinity)
    }

    private func question(_ text: String) -> some View {
        Text(text)
            .textSelection(.enabled)
            .padding(8)
            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func answer(_ turn: ChatTurn, index: Int) -> some View {
        let isLive = isAsking && index == turns.count - 1
        return VStack(alignment: .leading, spacing: 8) {
            if isLive { steps(showingThinking: !turn.thinking.isEmpty) }
            if !turn.thinking.isEmpty {
                // Open while the model is still thinking; folded once the answer starts
                DisclosureGroup(isExpanded: Binding(
                    get: { openThinking.contains(index) || (isLive && turn.text.isEmpty) },
                    set: { if $0 { openThinking.insert(index) } else { openThinking.remove(index) } }
                )) {
                    Text(turn.thinking)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(turn.seconds.map { localized("chat.thought", $0) } ?? localized("chat.step.thinking"),
                          systemImage: "brain")
                        .foregroundStyle(.secondary)
                }
            }
            if !turn.text.isEmpty { MarkdownText(text: turn.text) }
            if let seconds = turn.seconds {
                Text(localized("chat.seconds", seconds)).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    /// ✓ done · spinner now · ○ next, with seconds on the current step.
    private func steps(showingThinking: Bool) -> some View {
        let thinking: [Step] = showingThinking || step == .thinking ? [.thinking] : []
        let shown: [Step] = [.attached, .waiting] + thinking + [.writing]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(shown, id: \.self) { item in
                HStack(spacing: 6) {
                    Group {
                        if item < step {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        } else if item == step {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "circle").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 14)
                    Text(label(item)).foregroundStyle(item == step ? .primary : .secondary)
                    if item == step {
                        TimelineView(.periodic(from: startedAt, by: 1)) { context in
                            Text(localized("chat.seconds", Int(context.date.timeIntervalSince(startedAt))))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func label(_ item: Step) -> String {
        switch item {
        case .attached: localized("chat.step.attached", vm.items.count)
        case .waiting: localized("chat.step.waiting", agent.label)
        case .thinking: localized("chat.step.thinking")
        case .writing: localized("chat.step.writing")
        }
    }

    // MARK: - Input

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(localized("ai.ask"), text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)
                .accessibilityLabel(localized("ai.ask"))
            if isAsking {
                Button(localized("stop")) { reply?.cancel() }.controlSize(.small)
            } else {
                Button(localized("ai.send"), action: send)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
    }

    // MARK: - Sending

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }
        turns.append(ChatTurn(role: .user, text: question))
        input = ""
        chatError = nil
        // History = questions and answers only; streamed thinking stays on screen and is never sent back
        let history = turns.map { ChatTurn(role: $0.role, text: $0.text) }, settings = agent.settings
        let system = vm.agentContext   // replies in the script's language: they get copied into it
        turns.append(ChatTurn(role: .assistant, text: ""))
        let index = turns.count - 1
        startedAt = .now
        step = .waiting
        reply = Task {
            do {
                for try await event in AIService.stream(settings, system: system, turns: history) {
                    switch event {
                    case .thinking(let chunk):
                        step = .thinking
                        turns[index].thinking += chunk
                    case .text(let chunk):
                        step = .writing
                        turns[index].appendText(chunk)
                    }
                }
            } catch is CancellationError {
                // Stop: keep whatever arrived
            } catch let error as URLError where error.code == .cancelled {
                // Stop during the request
            } catch {
                chatError = error.localizedDescription
            }
            turns[index].seconds = Int(Date.now.timeIntervalSince(startedAt).rounded())
            if turns[index].text.isEmpty && turns[index].thinking.isEmpty { turns.remove(at: index) }
            reply = nil
        }
    }
}
