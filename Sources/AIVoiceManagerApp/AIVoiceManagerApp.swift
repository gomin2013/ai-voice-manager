import SwiftUI

@main
struct AIVoiceManagerApp: App {
    @State private var vm = EditorViewModel()
    @State private var playback = Playback()
    @State private var modelSheet: ModelPickerSheet.Mode?

    var body: some Scene {
        // Regular Dock / Launchpad app with one main window (like git-exclude-manager): ⌘Q / ⌘W from the app menu.
        Window(localized("app.title"), id: "main") {
            ContentView(modelSheet: $modelSheet)
                .environment(vm)
                .environment(playback)
                .frame(minWidth: 1440, minHeight: 760)   // both tool windows open (2 × 384) + the editor
                .sheet(item: $modelSheet) { ModelPickerSheet(mode: $0).environment(vm) }
                .onChange(of: vm.currentID) { playback.stop(); QuickPreview.shared.stop() }
        }
        .windowResizability(.contentMinSize)
        .commands {
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
