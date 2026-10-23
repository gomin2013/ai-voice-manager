import SwiftUI

/// Project name (double-click or ✎ to rename, never empty), Export / Generate →, the model line and every warning —
/// all under the name, nowhere else (prototype `.title-row` + `renderStatus`).
struct ProjectHeader: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.toolPanel") private var rightPanel = RightPanel.agent.rawValue
    @AppStorage("ui.leftPanel") private var leftPanel = LeftPanel.providers.rawValue
    @Binding var modelSheet: ModelPickerSheet.Mode?
    @State private var isRenaming = false
    @State private var name = ""
    @State private var nameError = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                title
                Spacer()
                Button {} label: { Label(localized("exportProject"), systemImage: "arrow.up.to.line") }
                    .glassButton()
                    // ponytail: Phase 2 writes no files — Export / Open Project… come with ProjectStore (Phase 3)
                    .disabled(true)
                    .help(localized("exportTip"))
                Button { rightPanel = RightPanel.generate.rawValue } label: {
                    Label { Text(localized("generateDots") + " →") } icon: { FloppyIcon.image }
                }
                .glassButton(prominent: true)
            }
            if nameError {
                Text(localized("titleEmpty")).font(.app(11.5)).foregroundStyle(.red)
            }
            modelLine
            notices
        }
        .onChange(of: vm.renameRequested) {
            if vm.renameRequested { vm.renameRequested = false; startRenaming() }
        }
    }

    @ViewBuilder
    private var title: some View {
        if isRenaming {
            TextField(localized("untitled"), text: $name)
                .textFieldStyle(.plain)
                .font(.app(18, .bold))
                .focused($nameFocused)
                .onSubmit(commit)
                .onExitCommand { isRenaming = false; nameError = false }
                .onChange(of: name) { if !name.trimmingCharacters(in: .whitespaces).isEmpty { nameError = false } }
                .onChange(of: nameFocused) { if !nameFocused { leave() } }
                .frame(maxWidth: 420)
        } else {
            HStack(spacing: 6) {
                Text(vm.draft.title).font(.app(18, .bold)).lineLimit(1)
                    .onTapGesture(count: 2, perform: startRenaming)
                Button(action: startRenaming) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(localized("rename"))
                    .accessibilityLabel(localized("rename"))
            }
        }
    }

    private func startRenaming() {
        name = vm.draft.title
        nameError = false
        isRenaming = true
        nameFocused = true
    }

    /// Return: save, or stay with the error when empty.
    private func commit() {
        if vm.rename(name) { isRenaming = false } else { nameError = true; nameFocused = true }
    }

    /// Focus out: save a name, cancel an empty one (like Finder).
    private func leave() {
        guard isRenaming else { return }
        if !vm.rename(name) { nameError = false }
        isRenaming = false
    }

    private var modelLine: some View {
        HStack(spacing: 8) {
            Text(verbatim: "✦").foregroundStyle(.secondary)
            Text(vm.model.name).font(.app(12.5, .semibold))
            Pill(text: localized("bTier"))
            Button(localized("modelChange")) { modelSheet = .change }.controlSize(.small)
        }
    }

    @ViewBuilder
    private var notices: some View {
        // ponytail: Phase 2 has no Keychain, so Google always reads as not connected (the prototype's first run)
        notice("🔑 " + localized("needKey"), button: "← " + localized("panel.providers")) {
            leftPanel = LeftPanel.providers.rawValue
        }
        if vm.model.readsThai == false && containsThai(plainText(of: vm.draft)) {
            notice(localized("thaiWarn"), button: localized("modelChange")) { modelSheet = .change }
        }
    }

    private func notice(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(text).font(.app(12))
            Button(button, action: action).controlSize(.small)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }
}

/// Every project starts by choosing its model; Change uses the same sheet and says what changes.
struct ModelPickerSheet: View {
    enum Mode: String, Identifiable { case new, change; var id: String { rawValue } }

    let mode: Mode
    @Environment(EditorViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var choice = ModelCatalog.standard.id

    var body: some View {
        let thaiText = mode == .change && containsThai(plainText(of: vm.draft))
        VStack(alignment: .leading, spacing: 12) {
            Text(localized(mode == .new ? "modelTitleNew" : "modelTitleChange")).font(.app(16, .bold))
            Text(localized("modelPhase")).font(.app(12)).foregroundStyle(.secondary)
            Picker(localized("modelTitleNew"), selection: $choice) {
                ForEach(ModelCatalog.all) { model in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(model.name).bold(); Pill(text: localized("bTier")) }
                        Text(localized(thaiKey(model))).font(.app(11.5)).foregroundStyle(.secondary)
                        if thaiText && model.readsThai == false {
                            Text("⚠ " + localized("thaiWarnPick")).font(.app(11.5)).foregroundStyle(.orange)
                        }
                    }
                    .tag(model.id)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if mode == .change {
                Text(localized("modelEffects")).font(.app(12)).foregroundStyle(.secondary)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            }
            HStack {
                Spacer()
                Button(localized("cancel"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(localized(mode == .new ? "createProject" : "useModel")) {
                    if mode == .new { vm.newProject(model: choice) } else { vm.setModel(choice) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { choice = mode == .new ? ModelCatalog.standard.id : vm.draft.model }
    }

    private func thaiKey(_ model: TTSModel) -> String {
        switch model.readsThai {
        case true: "thaiOk"
        case false: "thaiNo"
        case nil: "thaiUnknown"
        }
    }
}
