import SwiftUI

/// The middle of the window: project header, then Script Timeline | Current Scene, and the notice banner.
struct EditorView: View {
    @Environment(EditorViewModel.self) private var vm
    @Binding var modelSheet: ModelPickerSheet.Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectHeader(modelSheet: $modelSheet)
            HStack(alignment: .top, spacing: 10) {
                ScriptTimeline().frame(minWidth: 250, idealWidth: 330, maxWidth: 400)
                CurrentSceneView().frame(minWidth: 340, maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { NoticeBanner() }
    }
}

/// The prototype's toast: a message for a few seconds, with Undo when the action can be taken back.
private struct NoticeBanner: View {
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        if let notice = vm.notice {
            HStack(spacing: 10) {
                Text(notice.text).font(.app(12.5)).fixedSize(horizontal: false, vertical: true)
                if let undo = notice.undo {
                    Button(localized("undo")) { undo(); vm.notice = nil }.controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassSurface(cornerRadius: 12)
            .padding(.bottom, 18)
            .frame(maxWidth: 560)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: notice.id) {
                try? await Task.sleep(for: .seconds(notice.undo == nil ? 4 : 7))
                if vm.notice?.id == notice.id { vm.notice = nil }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
