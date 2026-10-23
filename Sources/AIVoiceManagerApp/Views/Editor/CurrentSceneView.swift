import SwiftUI

/// Current Scene (prototype `renderScene`). Script: voice box, style box, text with its footer and Quick preview,
/// and this scene's own Gemini preview player. Expression: the current tag and a drop zone to change it.
struct CurrentSceneView: View {
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        let item = vm.selectedItem
        VStack(alignment: .leading, spacing: 0) {
            Text(header(item)).font(.app(13, .semibold)).padding(10)
            Divider()
            ScrollView {
                switch item {
                case .script(let scene): ScriptSceneView(scene: scene).id(scene.id)
                case .expr(let scene): ExpressionSceneView(scene: scene)
                }
            }
        }
        .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }

    private func header(_ item: TimelineItem) -> String {
        let isExpression = if case .expr = item { true } else { false }
        return (isExpression ? "🎭 " : "🎬 ") + localized("currentScene") + " · "
            + localized(isExpression ? "expression" : "script") + " #\(vm.sceneNumber(item.id))"
    }
}

extension View {
    /// Dashed box that lights up while something hovers over it. `perform` returns false for a payload of the
    /// wrong kind (a voice on the expression slot …), which rejects the drop.
    func dropZone(perform: @escaping (DragPayload) -> Bool) -> some View {
        modifier(DropZone(perform: perform))
    }
}

private struct DropZone: ViewModifier {
    let perform: (DragPayload) -> Bool
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isTargeted ? AnyShapeStyle(.tint.opacity(0.1)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .dropDestination(for: String.self) { payloads, _ in
                payloads.compactMap(DragPayload.init).contains(where: perform)
            } isTargeted: { isTargeted = $0 }
    }
}

private struct ScriptSceneView: View {
    let scene: ScriptScene
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.toolPanel") private var rightPanel = RightPanel.agent.rawValue
    @AppStorage("ui.voiceTab") private var voiceTab = "voices"
    @State private var style = ""
    @State private var showsQuickPreview = false
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            voiceBox
            styleBox
            textBox
            ScenePreviewSection(scene: scene)
        }
        .padding(10)
        .onAppear { style = scene.style }
        .onChange(of: scene.style) { style = scene.style }
    }

    private var voiceBox: some View {
        let voice = vm.draft.speaker(scene.speaker).voice
        let info = VoiceCatalog.all.first { $0.name == voice }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VoiceWithStyle(voice: voice, style: scene.style, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(voice).bold().lineLimit(1).accessibilityLabel(localized("voice") + ": " + voice)
                    HStack(spacing: 6) {
                        if let info { GenderPill(gender: info.gender).fixedSize() }
                        Text(info?.description ?? "").foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Button(localized("panel.voices") + " →") { open(.voices, tab: "voices") }.controlSize(.small)
            }
            Text(localized("voiceHint")).font(.app(11.5)).foregroundStyle(.secondary)
        }
        .dropZone { payload in
            guard case .voice(let name) = payload else { return false }
            vm.useVoice(name)
            return true
        }
    }

    private func open(_ panel: RightPanel, tab: String) {
        voiceTab = tab
        rightPanel = panel.rawValue
    }

    private var styleBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StyleIcon(style: scene.style, size: 44)
                Text(localized("style"))
                TextField(localized("style"), text: $style)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { vm.setStyle(style, of: scene.id) }
                Button(localized("styleLib") + " →") { open(.voices, tab: "styles") }.controlSize(.small)
            }
            Text(localized("styleHint")).font(.app(11.5)).foregroundStyle(.secondary)
        }
        .dropZone { payload in
            guard case .style(let name) = payload else { return false }
            vm.setStyle(name, of: scene.id)
            return true
        }
    }

    private var textBox: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { showsQuickPreview.toggle() } label: {
                    Label(localized("quickPreview"), systemImage: "apple.logo")
                }
                .controlSize(.small)
                .help(localized("applePrev"))
                .popover(isPresented: $showsQuickPreview, arrowEdge: .bottom) {
                    QuickPreviewPopover(text: scene.text)
                }
            }
            .padding([.horizontal, .top], 6)
            TextEditor(text: Binding(get: { scene.text }, set: { vm.setText($0, of: scene.id) }))
                .font(.app(14))
                .scrollContentBackground(.hidden)
                .focused($textFocused)
                .frame(minHeight: 120)
                .padding(.horizontal, 8)
                .onChange(of: textFocused) { if !textFocused { vm.commitText(of: scene.id) } }
            Divider()
            HStack(spacing: 8) {
                Text(localized("chars", "\(scene.text.count)", "\(Int(estimateSeconds(scene.text).rounded()))"))
                    .lineLimit(1).layoutPriority(-1)
                Spacer(minLength: 4)
                Text(verbatim: "✦ qwen3.8").lineLimit(1).layoutPriority(-2).help(localized("aiHelp"))
                // ponytail: Ollama is Phase 3 (OllamaClient); Phase 2 says it's off, like the prototype offline
                Button(localized("oPolish")) { vm.notice = .init(text: localized("ollamaOff")) }
                Button(localized("oTags")) { vm.notice = .init(text: localized("ollamaOff")) }
            }
            .controlSize(.small)
            .font(.app(11.5))
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

/// "✦ PREVIEW THIS SCENE WITH GEMINI TTS": the scene's own player — greyed out until Generate preview.
private struct ScenePreviewSection: View {
    let scene: ScriptScene
    @Environment(EditorViewModel.self) private var vm
    @Environment(Playback.self) private var playback

    var body: some View {
        let ready = vm.readyPreview(of: scene)
        let busy = vm.previewBusy == scene.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("✦ " + localized("previewScene").uppercased())
                    .font(.app(11, .semibold)).foregroundStyle(.secondary)
                Pill(text: localized("bTier"))
            }
            MockPlayer(source: .scene(scene.id), duration: ready ?? estimateSeconds(scene.text),
                       seed: scene.id.hashValue)
                .disabled(ready == nil)
            HStack(spacing: 8) {
                if busy {
                    ProgressView().controlSize(.small)
                    Text(localized("pvBusy"))
                } else if ready != nil {
                    Pill(text: "✓ " + localized("pvReady"), color: .green)
                    Button("↻ " + localized("pvRegen"), action: generate).controlSize(.small)
                } else {
                    Button(localized("pvGen"), action: generate).glassButton(prominent: true)
                }
                let voice = vm.draft.speaker(scene.speaker).voice
                Text(localized("sceneOnly", vm.model.name.replacingOccurrences(of: "Gemini ", with: ""), voice))
                    .font(.app(11.5)).foregroundStyle(.secondary)
            }
        }
    }

    private func generate() { Task { await vm.generatePreview(of: scene) } }
}

private struct ExpressionSceneView: View {
    let scene: ExpressionScene
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.toolPanel") private var rightPanel = RightPanel.agent.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                ExpressionIcon(tag: scene.tag, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("curExpr")).foregroundStyle(.secondary)
                    Text("<\(vm.label(scene.tag))>").font(.app(22, .bold)).help(scene.tag.rawValue)
                    Text(localized("exd." + scene.tag.key) + " · " + localized("exprHint")).foregroundStyle(.secondary)
                }
                Spacer()
                Button(localized("panel.expressions") + " →") { rightPanel = RightPanel.expressions.rawValue }
                    .controlSize(.small)
            }
            Text(localized("exprDrop")).font(.app(11.5)).foregroundStyle(.secondary)
        }
        .dropZone { payload in
            guard case .expression(let tag) = payload else { return false }
            vm.setExpression(tag, of: scene.id)
            return true
        }
        .padding(10)
    }
}

struct GenderPill: View {
    let gender: Gender

    var body: some View {
        gender == .female
            ? Pill(text: "♀ " + localized("female"), color: Color(red: 0.95, green: 0.39, blue: 0.24))
            : Pill(text: "♂ " + localized("male"), color: Color(red: 0.18, green: 0.66, blue: 1))
    }
}
