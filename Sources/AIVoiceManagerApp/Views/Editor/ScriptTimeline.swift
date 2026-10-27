import SwiftUI

/// Script Timeline (prototype `renderTimeline`): every line and every breath / pause is a scene. Drag to reorder,
/// mute (left out of the take), delete; expressions dropped from Expression Library are inserted where they land.
struct ScriptTimeline: View {
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(localized("timeline")).font(.app(13, .semibold))
                Spacer()
                Button { vm.addScript() } label: { Label(localized("script"), systemImage: "plus") }
                    .controlSize(.small)
                Button { vm.addExpression() } label: { Label(localized("expression"), systemImage: "plus") }
                    .controlSize(.small)
            }
            .padding(10)
            Divider()
            List(selection: selection) {
                ForEach(vm.items) { item in
                    TimelineRow(item: item, canDelete: vm.items.count > 1).tag(item.id)
                }
                .onMove { vm.moveScenes(from: $0, to: $1) }
                .dropDestination(for: String.self) { payloads, index in
                    for case .expression(let tag) in payloads.compactMap(DragPayload.init) {
                        vm.insertExpression(tag, at: index)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            Divider()
            Text(symbols: footer)
                .font(.app(11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }

    private var selection: Binding<String?> {
        Binding(get: { vm.selectedItem.id }, set: { if let id = $0 { vm.select(id) } })
    }

    private var footer: String {
        let length = Duration.seconds(estimateSeconds(plainText(of: vm.draft))).formatted(.time(pattern: .minuteSecond))
        let muted = vm.items.filter(\.isMuted).count
        return localized("tlFoot", "\(vm.items.count)", "\(muted)", length) + " · " + localized("tlHint")
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let canDelete: Bool
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            label
            Spacer(minLength: 4)
            Button { vm.toggleMute(item.id) } label: {
                Image(systemName: item.isMuted ? "speaker.slash" : "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(item.isMuted ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            .help(localized(item.isMuted ? "unmute" : "mute"))
            .accessibilityLabel(localized(item.isMuted ? "unmute" : "mute"))
            Button { vm.removeScene(item.id) } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(!canDelete)
                .help(localized("remove"))
                .accessibilityLabel(localized("remove"))
        }
        .padding(.vertical, 2)
        .padding(.leading, isExpression ? 18 : 0)
        .opacity(item.isMuted ? 0.45 : 1)
    }

    private var isExpression: Bool { if case .expr = item { true } else { false } }

    @ViewBuilder
    private var label: some View {
        switch item {
        case .script(let scene):
            let voice = vm.draft.speaker(scene.speaker).voice
            VoiceWithStyle(voice: voice, style: scene.style, size: 28)
            let text = scene.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let line = text.isEmpty ? localized("empty") : String(text.prefix(80))
            (Text(VoiceDirectory.shared.name(voice)).bold() + Text(" — " + line))
                .lineLimit(1)
        case .expr(let scene):
            ExpressionIcon(tag: scene.tag, size: 22)
            Text("<\(vm.label(scene.tag))>").foregroundStyle(.secondary).help(scene.text)
            if scene.times > 1 { Text(verbatim: "×\(scene.times)").font(.app(11, .bold)).foregroundStyle(.tint) }
        }
    }
}
