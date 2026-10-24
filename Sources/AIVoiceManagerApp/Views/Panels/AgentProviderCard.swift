import SwiftUI

/// AI Providers › AI Agent: who answers the chat and rewrites scenes (Polish, Add pauses) — Hosts Manager's AI API
/// Settings sheet as a card: provider, then what that provider needs (nothing · Ollama status · key + model), and
/// what leaves the Mac. On-device providers first.
struct AgentProviderCard: View {
    @Environment(AgentSettings.self) private var agent
    @Environment(OllamaStatus.self) private var ollama
    @Environment(EditorViewModel.self) private var vm
    @State private var keyField = ""
    @State private var modelField = ""

    var body: some View {
        let provider = agent.settings.provider
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: Self.symbol(provider)).accessibilityHidden(true)
                Text(provider.displayName)
                Pill(text: localized(status), color: agent.isConfigured ? .green : .secondary)
            }
            .font(.app(12.5, .semibold))
            Picker(localized("settings.provider"), selection: Binding(get: { provider }, set: { agent.select($0) })) {
                ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
            }
            switch provider {
            case .apple: Text(localized("settings.appleNote")).foregroundStyle(.secondary)
            case .ollama: ollamaSection
            case .gemini, .openAI, .claude: cloudSection(provider)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .task(id: provider.rawValue + agent.settings.apiKey) { await agent.loadModels() }
        .onChange(of: vm.hasGeminiKey) { agent.reload() }   // the Voices tab saved or removed the Gemini key
    }

    private var status: String {
        if agent.isConfigured { return "connected" }
        return agent.settings.provider == .ollama ? "notRunning" : "notConnected"
    }

    @ViewBuilder
    private var ollamaSection: some View {
        Text(localized("ollamaUse"))
        if ollama.isRunning {
            let model = Binding(get: { agent.settings.model }, set: { agent.setModel($0) })
            Picker(localized("settings.model"), selection: model) {
                ForEach(ollama.models, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        } else {
            Text(localized("ollamaHow")).foregroundStyle(.secondary)
        }
        HStack {
            Text(verbatim: "localhost:11434").font(.data(11)).foregroundStyle(.secondary)
            Spacer()
            Button(localized("checkAgain")) { Task { await ollama.probe(); await agent.loadModels() } }
        }
    }

    @ViewBuilder
    private func cloudSection(_ provider: AIProvider) -> some View {
        if provider == .gemini {
            Label(localized("agentGeminiKey"), systemImage: "key").foregroundStyle(.secondary)
        } else {
            HStack {
                // Never shows the saved key: typing a new one replaces it
                SecureField(text: $keyField,
                            prompt: Text(verbatim: agent.settings.apiKey.isEmpty ? "" : "••••••••")) {
                    Text(localized("settings.apiKey"))
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveKey)
                Button(localized("save"), action: saveKey)
                    .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        HStack {
            if !agent.models.isEmpty {
                Menu(localized("settings.model")) {
                    ForEach(agent.models, id: \.self) { model in
                        Button(AIService.modelLabel(model, provider: provider)) { agent.setModel(model) }
                    }
                }
                .fixedSize()
            }
            TextField(localized("settings.model"), text: $modelField, prompt: Text(verbatim: agent.settings.model))
                .textFieldStyle(.roundedBorder)
                .onSubmit { agent.setModel(modelField); modelField = "" }
        }
        if provider != .gemini {
            Text(localized("settings.keychainNote")).foregroundStyle(.secondary)
        }
        Label(localized("agentPrivacy"), systemImage: "exclamationmark.shield").foregroundStyle(.orange)
    }

    private func saveKey() {
        agent.setKey(keyField)
        keyField = ""
    }

    private static func symbol(_ provider: AIProvider) -> String {
        switch provider {
        case .apple: "apple.logo"
        case .ollama: "desktopcomputer"
        case .gemini, .openAI, .claude: "cloud"
        }
    }
}
