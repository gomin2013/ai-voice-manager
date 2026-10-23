import SwiftUI

/// History like Hosts Manager (prototype `panel_history`): Pinned (yours newest first, then When Opened), Recent
/// (newest first, the top one is Now). ↩ or double-click goes back — as a new step, so nothing is lost.
struct HistoryPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @State private var renaming: HistoryStep<ProjectDraft>?
    @State private var newName = ""

    var body: some View {
        let history = vm.history
        VStack(alignment: .leading, spacing: 0) {
            Button { vm.pinCurrent() } label: { Label(localized("hist.pin"), systemImage: "pin") }
                .controlSize(.small)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    header(localized("hist.pinned"))
                    ForEach(history.pinned) { step in
                        row(step, isCurrent: step.snapshot == vm.draft, icon: step.isOpened ? "doc" : "pin.fill") {
                            if !step.isOpened {
                                small("pencil", localized("hist.rename")) { newName = step.label; renaming = step }
                                small("xmark", localized("hist.unpin")) { vm.unpin(step.id) }
                            }
                        }
                    }
                    header(localized("hist.recent"))
                    ForEach(history.steps.reversed()) { step in
                        let isCurrent = step.id == history.current?.id
                        row(step, isCurrent: isCurrent, icon: isCurrent ? "largecircle.fill.circle" : "circle") {
                            if !isCurrent { small("trash", localized("hist.remove")) { vm.removeStep(step.id) } }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .alert(localized("hist.rename"), isPresented: isRenaming) {
            TextField(localized("hist.rename"), text: $newName)
            Button(localized("cancel"), role: .cancel) {}
            Button(localized("save")) { if let step = renaming { vm.renamePin(step.id, to: newName) } }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased()).font(.app(11, .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.top, 10).padding(.bottom, 4)
    }

    private func row(_ step: HistoryStep<ProjectDraft>, isCurrent: Bool, icon: String,
                     @ViewBuilder extra: () -> some View) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.label).fontWeight(isCurrent ? .semibold : .regular).lineLimit(1).truncationMode(.middle)
                Text(step.date, style: .time).font(.app(11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if isCurrent {
                Text(localized("hist.now")).font(.app(11, .semibold)).foregroundStyle(.tint)
            } else {
                small("arrow.uturn.backward", localized("hist.restore")) { vm.restore(step.id) }
            }
            extra()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isCurrent ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !isCurrent { vm.restore(step.id) } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func small(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(label)
            .accessibilityLabel(label)
    }
}
