import SwiftUI

/// History, the same panel as Hosts Manager's HistoryPanel, in two tabs of 30 each:
/// - Script: Pinned (yours newest first, then When Opened) and Recent project steps (the top one is Now).
/// - Scene: the Script scenes' text versions (`SceneHistory`) — going back changes only that scene's text.
/// ↩, double-click or right-click › Restore goes back as a new step, so nothing is lost. Dates in the app's language
/// (Hosts Manager uses the system's).
struct HistoryPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.historyTab") private var tab = "script"
    @State private var renaming: HistoryStep<ProjectDraft>?
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker(localized("panel.history"), selection: $tab) {
                    Text(localized("script")).tag("script")
                    Text(localized("hist.tabScene")).tag("scene")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
                if tab == "script" {
                    Button { vm.pinCurrent() } label: { Image(systemName: "pin") }
                        .buttonStyle(.borderless)
                        .help(localized("hist.pin"))
                        .accessibilityLabel(localized("hist.pin"))
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            if tab == "scene" { sceneList } else { scriptList }
        }
        .alert(localized("hist.rename"), isPresented: isRenaming) {
            TextField(localized("hist.rename"), text: $newName)
            Button(localized("cancel"), role: .cancel) {}
            Button(localized("save")) { if let step = renaming { vm.renamePin(step.id, to: newName) } }
        }
    }

    // MARK: - Script: project steps

    private var scriptList: some View {
        let history = vm.history
        return List {
            Section(localized("hist.pinned")) {
                ForEach(history.pinned) { step in
                    let isCurrent = step.snapshot == vm.draft
                    row(Row(title: step.label, date: step.date, icon: step.isOpened ? "doc" : "pin.fill",
                            isCurrent: isCurrent, restore: { vm.restore(step.id) }))
                        .contextMenu {
                            restoreButton(isCurrent: isCurrent) { vm.restore(step.id) }
                            if !step.isOpened {
                                Button(localized("hist.rename")) { newName = step.label; renaming = step }
                                Button(localized("hist.unpin")) { vm.unpin(step.id) }
                            }
                        }
                }
            }
            Section(localized("hist.recent")) {
                ForEach(history.steps.reversed()) { step in
                    // Only the newest step is "Now"; an older step with the same project is a past version of it
                    let isCurrent = step.id == history.current?.id
                    row(Row(title: step.label, date: step.date, icon: isCurrent ? "largecircle.fill.circle" : "circle",
                            isCurrent: isCurrent, restore: { vm.restore(step.id) },
                            remove: isCurrent ? nil : { vm.removeStep(step.id) }))
                        .contextMenu {
                            restoreButton(isCurrent: isCurrent) { vm.restore(step.id) }
                            Button(localized("hist.pinThis")) { vm.pin(step.id) }
                            if !isCurrent {
                                Divider()
                                Button(localized("hist.remove"), role: .destructive) { vm.removeStep(step.id) }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Scene: text versions

    private var sceneList: some View {
        let history = vm.sceneHistory
        return List {
            if history.edits.isEmpty {
                Text(localized("hist.sceneEmpty")).foregroundStyle(.secondary)
            }
            ForEach(history.edits.reversed()) { edit in
                let isCurrent = history.isCurrent(edit)
                row(Row(title: edit.label, date: edit.date, icon: isCurrent ? "largecircle.fill.circle" : "circle",
                        isCurrent: isCurrent, restore: { vm.restoreSceneText(edit.id) },
                        remove: isCurrent ? nil : { vm.removeSceneEdit(edit.id) }))
                    .help(edit.text)   // which words this version has
                    .contextMenu {
                        restoreButton(isCurrent: isCurrent) { vm.restoreSceneText(edit.id) }
                        if !isCurrent {
                            Divider()
                            Button(localized("hist.remove"), role: .destructive) { vm.removeSceneEdit(edit.id) }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Rows

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    /// One row of either tab.
    private struct Row {
        let title: String, date: Date, icon: String
        let isCurrent: Bool
        let restore: () -> Void
        /// Shows a trash button; nil for rows that can't be removed ("Now", pins).
        var remove: (() -> Void)?
    }

    private func row(_ item: Row) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .foregroundStyle(item.isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).lineLimit(1).fontWeight(item.isCurrent ? .semibold : .regular)
                Text(Self.when(item.date)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if item.isCurrent {
                Text(localized("hist.now"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            } else {
                Button(action: item.restore) { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.borderless)
                    .help(localized("hist.restore"))
                    .accessibilityLabel(localized("hist.restore"))
                if let remove = item.remove {
                    Button(action: remove) { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(localized("hist.remove"))
                        .accessibilityLabel(localized("hist.remove"))
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // Double-click = restore, like double-clicking a step in Photoshop's History panel
        .onTapGesture(count: 2) { if !item.isCurrent { item.restore() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isCurrent ? .isSelected : [])
        .accessibilityAction(named: localized("hist.restore")) { if !item.isCurrent { item.restore() } }
    }

    private func restoreButton(isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(localized("hist.restore"), action: action).disabled(isCurrent)
    }

    /// Today: time only. Earlier: day, month and time — Hosts Manager's format, in the app's language.
    private static func when(_ date: Date) -> String {
        let locale = Locale(identifier: LanguageService.shared.current.rawValue)
        let style: Date.FormatStyle = Calendar.current.isDateInToday(date)
            ? .dateTime.hour().minute() : .dateTime.day().month().hour().minute()
        return date.formatted(style.locale(locale))
    }
}
