import SwiftUI

/// Current Scene (prototype `renderScene`). Script: voice box, style box, text with its footer and Quick preview,
/// and this scene's own Gemini preview player. Expression: the current tag and a drop zone to change it.
struct CurrentSceneView: View {
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        let item = vm.selectedItem
        VStack(alignment: .leading, spacing: 0) {
            header(item).font(.app(13, .semibold)).padding(10)
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

    private func header(_ item: TimelineItem) -> Text {
        let isExpression = if case .expr = item { true } else { false }
        let title = localized("currentScene") + " · " + localized(isExpression ? "expression" : "script")
            + " #\(vm.sceneNumber(item.id))"
        return Text("\(Image(systemName: isExpression ? "face.smiling" : "movieclapper")) \(title)")
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
    @Environment(AgentSettings.self) private var agent
    @AppStorage("ui.leftPanel") private var leftPanel = LeftPanel.providers.rawValue
    @AppStorage("ui.providersTab") private var providersTab = "voices"
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
        let info = VoiceDirectory.shared.voice(voice)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VoiceWithStyle(voice: voice, style: scene.style, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(info?.name ?? voice).bold().lineLimit(1)
                        .accessibilityLabel(localized("voice") + ": " + (info?.name ?? voice))
                    HStack(spacing: 6) {
                        if let info { GenderPill(gender: info.gender).fixedSize() }
                        Text(info.map { $0.isBuiltin ? $0.description : $0.persona } ?? "")
                            .foregroundStyle(.secondary).lineLimit(1).help(info?.description ?? "")
                    }
                }
                Spacer(minLength: 4)
                Button { open(.voices, tab: "voices") } label: { ChevronLabel(localized("panel.voices")) }
                    .controlSize(.small)
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
                Button { open(.voices, tab: "styles") } label: { ChevronLabel(localized("styleLib")) }
                    .controlSize(.small)
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
                // A pause in typing is one History › Scene row too, not only leaving the editor
                .task(id: scene.text) {
                    try? await Task.sleep(for: .seconds(1.5))
                    if !Task.isCancelled { vm.commitText(of: scene.id) }
                }
            Divider()
            HStack(spacing: 8) {
                Text(localized("chars", "\(scene.text.count)", "\(Int(estimateSeconds(scene.text).rounded()))"))
                    .lineLimit(1).layoutPriority(-1)
                Spacer(minLength: 4)
                // Apple Foundation Models doesn't rewrite scenes: no ✦ buttons. Ollama / Gemini / OpenAI / Claude do.
                if agent.settings.provider != .apple {
                    Text(verbatim: "✦ " + (agent.label.split(separator: ":").first.map(String.init) ?? agent.label))
                        .lineLimit(1).layoutPriority(-2).help(localized("aiHelp"))
                    if vm.aiBusy == scene.id {
                        ProgressView().controlSize(.mini)
                        Text(localized("ai.thinking"))
                    } else {
                        Button(localized("oPolish")) { rewrite(.polish) }.disabled(vm.aiBusy != nil)
                        Button(localized("oTags")) { rewrite(.pauses) }.disabled(vm.aiBusy != nil)
                    }
                }
            }
            .controlSize(.small)
            .font(.app(11.5))
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }

    /// ✦ Polish / Add pauses: the AI Agent rewrites this scene (one History step); not set up → AI Providers › AI Agent.
    private func rewrite(_ kind: EditorViewModel.Rewrite) {
        vm.commitText(of: scene.id)
        guard agent.isConfigured else {
            providersTab = "agent"
            leftPanel = LeftPanel.providers.rawValue
            return
        }
        Task { await vm.rewrite(kind, sceneID: scene.id, settings: agent.settings) }
    }
}

/// "✦ PREVIEW THIS SCENE WITH GEMINI TTS": the scene's own player — greyed out until Generate preview.
private struct ScenePreviewSection: View {
    let scene: ScriptScene
    @Environment(EditorViewModel.self) private var vm
    @Environment(ConnectionMonitor.self) private var net
    @Environment(Playback.self) private var playback

    var body: some View {
        let ready = vm.readyPreview(of: scene)
        let busy = vm.previewBusy == scene.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("✦ " + localized("previewScene").uppercased())
                    .font(.app(11, .semibold)).foregroundStyle(.secondary)
                TierPill()
            }
            PlayerBar(source: .scene(scene.id), duration: ready?.duration ?? estimateSeconds(scene.text),
                      seed: scene.id.hashValue, audio: ready.map { .data($0.audio) }, heights: ready?.heights)
                .disabled(ready == nil)
            HStack(spacing: 8) {
                if busy {
                    ProgressView().controlSize(.small)
                    Text(localized("pvBusy"))
                } else if ready != nil {
                    Pill(text: "✓ " + localized("pvReady"), color: .green)
                    Button("↻ " + localized("pvRegen"), action: generate).controlSize(.small)
                        .disabled(!net.isOnline).help(net.isOnline ? "" : localized("netNeeds"))
                } else {
                    Button(localized("pvGen"), action: generate).glassButton(prominent: true)
                        .disabled(!net.isOnline).help(net.isOnline ? "" : localized("netNeeds"))
                }
                let voice = vm.draft.speaker(scene.speaker).voice
                Text(localized("sceneOnly", vm.model.name.replacingOccurrences(of: "Gemini ", with: ""),
                               VoiceDirectory.shared.name(voice)))
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
                    Picker(localized("repeat"), selection: Binding(get: { scene.times },
                                                                    set: { vm.setTimes($0, of: scene.id) })) {
                        ForEach(1...ExpressionScene.maxTimes, id: \.self) { Text(verbatim: "×\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .controlSize(.small)
                    .help(localized("repeatTip"))
                }
                Spacer()
                Button { rightPanel = RightPanel.expressions.rawValue } label: {
                    ChevronLabel(localized("panel.expressions"))
                }
                .controlSize(.small)
                .fixedSize()   // the description wraps instead; a narrow editor truncated the button
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

/// Button title with a chevron (prototype `.to-right` / `.to-left`): "go to that panel".
struct ChevronLabel: View {
    let title: String
    var back = false

    init(_ title: String, back: Bool = false) {
        self.title = title
        self.back = back
    }

    var body: some View {
        HStack(spacing: 4) {
            if back { chevron("chevron.left") }
            Text(title)
            if !back { chevron("chevron.right") }
        }
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 9, weight: .bold)).accessibilityHidden(true)
    }
}

struct GenderPill: View {
    let gender: Gender

    /// The symbol only; the word is the tooltip and the VoiceOver label.
    var body: some View {
        let word = localized(gender.rawValue)
        Pill(text: gender == .female ? "♀" : gender == .male ? "♂" : "○", color: Self.color(gender))
            .help(word).accessibilityLabel(word)
    }

    static func color(_ gender: Gender) -> Color {
        switch gender {
        case .female: Color(red: 0.95, green: 0.39, blue: 0.24)
        case .male: Color(red: 0.18, green: 0.66, blue: 1)
        case .neutral: Color.gray
        }
    }
}
