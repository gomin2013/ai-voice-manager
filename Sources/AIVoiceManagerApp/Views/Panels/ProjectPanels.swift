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
                // ponytail: Open Project… reads a file — ProjectStore, Phase 3 (clean(imported:) is ready and tested)
                Button {} label: { Label(localized("openProject"), systemImage: "arrow.down.to.line") }
                    .disabled(true)
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

/// AI Providers (left rail, bottom): getting started, Google, Ollama, Apple. Phase 2 = static mock states:
/// no Keychain (key Save / Test / Remove come in Phase 3) and no network (Ollama reads as not running).
struct AIProvidersPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("gemini.tier") private var tier = "free"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(localized("getStarted")).font(.app(12, .semibold)).foregroundStyle(.secondary)
                ForEach(Array(["stepGoogle", "stepOllama", "stepProject"].enumerated()), id: \.offset) { index, key in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).").monospacedDigit()
                        Text(localized(key))
                    }
                }
                card(title: "✦ Google · Gemini TTS", status: localized("notConnected"), ok: false) {
                    Text(localized("googleUse"))
                    HStack {
                        SecureField(text: .constant(""), prompt: Text(verbatim: "AIza…")) {
                            Text(verbatim: "Gemini API key")
                        }
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        Button(localized("save")) {}.disabled(true)
                    }
                    Picker(localized("tierFree"), selection: $tier) {
                        Text(localized("tierFree")).tag("free")
                        Text(localized("tierPaid")).tag("paid")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    HStack {
                        Button(localized("testConn")) {}.disabled(true)
                        Link(localized("getKey"), destination: URL(string: "https://aistudio.google.com/apikey")!)
                        Link(localized("pricing"), destination: URL(string: "https://ai.google.dev/gemini-api/docs/pricing")!)
                    }
                    Text(localized("keyNote")).foregroundStyle(.secondary)
                }
                card(title: "🦙 Ollama · " + localized("onThisMac"), status: localized("notRunning"), ok: false) {
                    Text(localized("ollamaUse"))
                    Text(localized("ollamaHow")).foregroundStyle(.secondary)
                    Text(verbatim: "localhost:11434").font(.data(11)).foregroundStyle(.secondary)
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
