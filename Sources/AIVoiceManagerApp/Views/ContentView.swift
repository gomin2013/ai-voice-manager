import AppKit
import SwiftUI

/// The window: left tool window (Recent Projects · AI Providers) | editor | right tool window (History, libraries,
/// Generate, AI Agent, Help · Appearance, Language, About) — the prototype's layout.
struct ContentView: View {
    /// @AppStorage can't hold an Optional: "" = hidden. AI Providers opens first until Google is connected (Phase 3).
    @AppStorage("ui.leftPanel") private var leftRaw = LeftPanel.providers.rawValue
    @AppStorage("ui.toolPanel") private var rightRaw = RightPanel.agent.rawValue
    @AppStorage("ui.accent") private var accent = AccentChoice.system
    @AppStorage("ui.gradient") private var theme = GradientTheme.none
    @AppStorage("app.appearance") private var appearance = Appearance.system
    @Binding var modelSheet: ModelPickerSheet.Mode?

    var body: some View {
        // Reading `current` here re-renders the window when the language changes (localized() reads the bundle).
        let language = LanguageService.shared.current
        HStack(spacing: 0) {
            ToolWindow(panel: binding($leftRaw, as: LeftPanel.self), edge: .leading) { panel in
                switch panel {
                case .projects: RecentProjectsPanel(modelSheet: $modelSheet)
                case .providers: AIProvidersPanel()
                }
            }
            EditorView(modelSheet: $modelSheet)
                .frame(minWidth: 660, maxWidth: .infinity, maxHeight: .infinity)
            ToolWindow(panel: binding($rightRaw, as: RightPanel.self), theme: theme) { panel in
                switch panel {
                case .help: HelpPanel()
                case .appearance: AppearancePanel()
                case .language: LanguagePanel()
                case .about: AboutPanel()
                case .history: HistoryPanel()
                case .voices: VoiceLibraryPanel()
                case .expressions: ExpressionLibraryPanel()
                case .generate: GeneratePanel()
                case .agent: AgentPanel()
                }
            }
        }
        .font(.app(13))
        .tint((AccentChoice.launchOverride ?? accent).color)
        .environment(\.locale, Locale(identifier: language.rawValue))
        .onAppear { NSApp.appearance = appearance.nsAppearance }
        .onChange(of: appearance) { NSApp.appearance = appearance.nsAppearance }
    }

    private func binding<Panel: RailPanel>(_ raw: Binding<String>, as: Panel.Type) -> Binding<Panel?> {
        Binding(get: { Panel(rawValue: raw.wrappedValue) }, set: { raw.wrappedValue = $0?.rawValue ?? "" })
    }
}
