import SwiftUI

/// Recent Projects (left rail, top): names + "Opened …", search, click to switch, ✕ forgets the entry.
struct RecentProjectsPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @Binding var modelSheet: ModelPickerSheet.Mode?
    @State private var query = ""

    var body: some View {
        let rows = vm.recentProjects.filter { query.isEmpty || $0.draft.title.localizedCaseInsensitiveContains(query) }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button { modelSheet = .new } label: { Label(localized("newProject"), systemImage: "plus") }
                    .glassButton(prominent: true)
                Button(action: openFile) { Label(localized("openProject"), systemImage: "arrow.down.to.line") }
                    .help(localized("openTip"))
            }
            .controlSize(.small)
            .padding(.horizontal, 14)
            TextField(localized("projSearch"), text: $query).textFieldStyle(.roundedBorder).padding(.horizontal, 14)
            if rows.isEmpty { Text(localized("noMatch")).foregroundStyle(.secondary).padding(.horizontal, 14) }
            List(rows) { project in
                let isOpen = project.id == vm.currentID
                HStack(spacing: 8) {
                    Image(systemName: isOpen ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.draft.title).fontWeight(isOpen ? .semibold : .regular).lineLimit(1)
                        Text(localized("opened", project.opened.inAppLanguage))
                            .font(.app(11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button { vm.removeProject(project.id) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .disabled(vm.projects.count < 2)
                        .help(localized("removeProject"))
                        .accessibilityLabel(localized("removeProject"))
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .onTapGesture { vm.switchProject(to: project.id) }
                .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { vm.switchProject(to: project.id) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

extension RecentProjectsPanel {
    /// Open Project…: an exported `.avmproject.zip` (with takes) or a `.json` becomes a new project.
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip, .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vm.open(url)
    }
}

/// AI Providers (left rail, bottom): getting started, Google (Keychain + Test), Ollama (status, model, Check
/// again), Apple.
struct AIProvidersPanel: View {
    @Environment(OllamaStatus.self) private var ollama
    @Environment(EditorViewModel.self) private var vm
    @Environment(ConnectionMonitor.self) private var net
    @AppStorage("gemini.tier") private var tier = "free"
    @State private var keyField = ""
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(localized("getStarted")).font(.app(12, .semibold)).foregroundStyle(.secondary)
                let done = [vm.hasGeminiKey, ollama.isRunning, vm.hasGeminiKey]   // the prototype's three checks
                ForEach(Array(["stepGoogle", "stepOllama", "stepProject"].enumerated()), id: \.offset) { index, key in
                    HStack(alignment: .top, spacing: 8) {
                        Text(done[index] ? "✅" : "\(index + 1).").monospacedDigit()
                        Text(localized(key))
                    }
                }
                card(title: "✦ Google · Gemini TTS",
                     status: localized(vm.hasGeminiKey ? "connected" : "notConnected"), ok: vm.hasGeminiKey) {
                    Text(localized("googleUse"))
                    HStack {
                        // Never shows the saved key: typing a new one replaces it
                        SecureField(text: $keyField, prompt: Text(verbatim: vm.hasGeminiKey ? "••••••••" : "AIza…")) {
                            Text(verbatim: "Gemini API key")
                        }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                        Button(localized("save"), action: save)
                            .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Picker(localized("tierFree"), selection: $tier) {
                        Text(localized("tierFree")).tag("free")
                        Text(localized("tierPaid")).tag("paid")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    HStack {
                        Button(localized("testConn")) {
                            isTesting = true
                            testResult = localized("testing")
                            Task {
                                testResult = await vm.testGeminiKey()
                                isTesting = false
                            }
                        }
                        .disabled(!vm.hasGeminiKey || isTesting || !net.isOnline)
                        .help(net.isOnline ? "" : localized("netNeeds"))
                        if vm.hasGeminiKey {
                            Button(localized("removeKey")) {
                                vm.removeGeminiKey()
                                testResult = ""
                            }
                        }
                    }
                    HStack {   // own row: with Test + Remove the 300 pt card truncated every button
                        Link(localized("getKey"), destination: URL(string: "https://aistudio.google.com/apikey")!)
                        Link(localized("pricing"), destination: URL(string: "https://ai.google.dev/gemini-api/docs/pricing")!)
                    }
                    if !testResult.isEmpty {
                        Text(testResult).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Text(localized("keyNote")).foregroundStyle(.secondary)
                }
                card(title: "🦙 Ollama · " + localized("onThisMac"),
                     status: localized(ollama.isRunning ? "connected" : "notRunning"), ok: ollama.isRunning) {
                    Text(localized("ollamaUse"))
                    if ollama.isRunning {
                        @Bindable var ollama = ollama
                        Picker(localized("ai.model"), selection: $ollama.model) {
                            ForEach(ollama.models, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    } else {
                        Text(localized("ollamaHow")).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(verbatim: "localhost:11434").font(.data(11)).foregroundStyle(.secondary)
                        Spacer()
                        Button(localized("checkAgain")) { Task { await ollama.probe() } }
                    }
                }
                card(title: " Apple · " + localized("onThisMac"), status: localized("quickPreview"), ok: true) {
                    Text(localized("appleUse"))
                }
            }
            .font(.app(12))
            .controlSize(.small)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private func save() {
        if vm.saveGeminiKey(keyField) {
            keyField = ""
            testResult = ""
        }
    }

    private func card(title: String, status: String, ok: Bool,
                      @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.app(12.5, .semibold))
                Pill(text: status, color: ok ? .green : .secondary)
            }
            content().fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}
