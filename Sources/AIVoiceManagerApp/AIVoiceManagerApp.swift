import SwiftUI

@main
struct AIVoiceManagerApp: App {
    @State private var vm = EditorViewModel.launch()
    @State private var playback = Playback()
    @State private var net = ConnectionMonitor()
    @State private var ollama = OllamaStatus()
    @State private var agent = AgentSettings()
    @State private var modelSheet: ModelPickerSheet.Mode?

    var body: some Scene {
        // Regular Dock / Launchpad app with one main window (like git-exclude-manager): ⌘Q / ⌘W from the app menu.
        Window(localized("app.title"), id: "main") {
            ContentView(modelSheet: $modelSheet)
                .environment(vm)
                .environment(playback)
                .environment(net)
                .environment(ollama)
                .environment(agent)
                .task { net.start() }
                .task { await ollama.probe() }
                .task { await VoiceDirectory.shared.refreshIfStale(key: KeychainStore.load()) }   // weekly, free
                .task { await UpdateChecker.checkIfDue() }   // off unless turned on in About
                .frame(minWidth: 1440, minHeight: 760)   // both tool windows open (2 × 384) + the editor
                .sheet(item: $modelSheet) { ModelPickerSheet(mode: $0).environment(vm).environment(net) }
                .onChange(of: vm.currentID) { playback.stop(); QuickPreview.shared.stop() }
                // Text is committed on focus-out; quitting mid-sentence still saves what's typed
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    vm.save(vm.project)
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(localized("update.check")) { Task { await UpdateChecker.check(manual: true) } }
            }
            // One main window: File › New Window becomes New Project (every project starts by choosing its model).
            CommandGroup(replacing: .newItem) {
                Button(localized("newProject")) { modelSheet = .new }.keyboardShortcut("n")
            }
            CommandGroup(after: .newItem) {
                Button(localized("generate")) {
                    UserDefaults.standard.set(RightPanel.generate.rawValue, forKey: "ui.toolPanel")
                    vm.generateRequested = true
                }
                .keyboardShortcut(.return)
                .disabled(vm.isGenerating)
            }
        }
    }
}
