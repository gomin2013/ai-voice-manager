import Foundation

/// Script Timeline and Current Scene edits — one History step each (the prototype's addItem, dropItem, toggleMute,
/// removeItem, setSceneStyle, setExpr, setSceneVoice). Scene numbers in labels are 1-based, as the user sees them.
extension EditorViewModel {
    var items: [TimelineItem] { draft.items }

    /// The selected scene; the first one when nothing (or a deleted scene) is selected.
    var selectedItem: TimelineItem {
        items.first { $0.id == project.selection } ?? items[0]
    }

    func select(_ id: String) {
        guard items.contains(where: { $0.id == id }) else { return }
        project.selection = id
    }

    func sceneNumber(_ id: String) -> Int { (items.firstIndex { $0.id == id } ?? 0) + 1 }

    /// New scenes go right after the selected one; a new Script takes the speaker and style of the line above it.
    func addScript() {
        let at = (items.firstIndex { $0.id == selectedItem.id } ?? -1) + 1
        let above = items[..<at].reversed().lazy
            .compactMap { if case .script(let scene) = $0 { scene } else { nil } }.first
        insert(.script(ScriptScene(speaker: above?.speaker ?? .s1, style: above?.style ?? "Friendly")), at: at,
               label: localized("hist.addScript"))
    }

    /// `+ Expression` / Insert in Expression Library: after the selected scene.
    func addExpression(_ tag: ExpressionTag = .breath) {
        let at = (items.firstIndex { $0.id == selectedItem.id } ?? -1) + 1
        insert(.expr(ExpressionScene(tag: tag)), at: at, label: localized("hist.addExpr", label(tag)))
    }

    /// Dropped from Expression Library onto the timeline: lands at `index` (the drop position).
    func insertExpression(_ tag: ExpressionTag, at index: Int) {
        insert(.expr(ExpressionScene(tag: tag)), at: min(max(index, 0), items.count),
               label: localized("hist.addExpr", label(tag)))
    }

    private func insert(_ item: TimelineItem, at index: Int, label: String) {
        draft.items.insert(item, at: index)
        project.selection = item.id
        record(label)
    }

    /// Drag ⋮⋮ (List .onMove).
    func moveScenes(from source: IndexSet, to destination: Int) {
        let before = draft.items
        draft.items.move(fromOffsets: source, toOffset: destination)
        if draft.items != before { record(localized("hist.move")) }
    }

    func toggleMute(_ id: String) {
        guard let at = items.firstIndex(where: { $0.id == id }) else { return }
        draft.items[at].isMuted.toggle()
        record(localized(draft.items[at].isMuted ? "hist.mute" : "hist.unmute", "\(at + 1)"))
    }

    /// The last scene stays (the timeline is never empty); selection moves to the neighbour.
    func removeScene(_ id: String) {
        guard items.count > 1, let at = items.firstIndex(where: { $0.id == id }) else { return }
        draft.items.remove(at: at)
        if project.selection == id { project.selection = items[min(at, items.count - 1)].id }
        record(localized("hist.removeScene", "\(at + 1)"))
    }

    /// Typing changes the text without a History step; `commitText` records one when the editor loses focus.
    func setText(_ text: String, of id: String) {
        update(id) { $0.text = String(text.prefix(10_000)) }
    }

    /// Typing pauses or the editor loses focus: the scene's new text becomes one History › Scene row.
    func commitText(of id: String) { recordSceneText(of: id) }

    func setStyle(_ style: String, of id: String) {
        let style = String(style.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !style.isEmpty, case .script(let scene) = items.first(where: { $0.id == id }), scene.style != style
        else { return }
        update(id) { $0.style = style }
        record(localized("hist.style", "\(sceneNumber(id))", style))
    }

    /// Voice Library Apply / drop: the selected Script scene gets the voice under the two-voice limit.
    func useVoice(_ voice: String) {
        guard case .script(let scene) = selectedItem else { notice = Notice(text: localized("pickScript")); return }
        switch assignVoice(voice, to: scene.id, in: &draft) {
        case .unchanged: break
        case .assigned: record(localized("hist.voice", voice))
        case .refused(let inUse): notice = Notice(text: localized("twoVoices", inUse[0], inUse[1]))
        }
    }

    /// Expression Library Apply / drop on the Current Scene: changes the selected expression.
    func setExpression(_ tag: ExpressionTag, of id: String) {
        guard let at = items.firstIndex(where: { $0.id == id }), case .expr(var scene) = items[at], scene.tag != tag
        else { return }
        scene.tag = tag
        draft.items[at] = .expr(scene)
        record(localized("hist.expr", label(tag)))
    }

    /// Repeat ×1…×10 (clamped by `ExpressionScene`).
    func setTimes(_ times: Int, of id: String) {
        guard let at = items.firstIndex(where: { $0.id == id }), case .expr(var scene) = items[at] else { return }
        let old = scene.times
        scene.times = min(ExpressionScene.maxTimes, max(1, times))
        guard scene.times != old else { return }
        draft.items[at] = .expr(scene)
        record(localized("hist.times", label(scene.tag), "\(scene.times)"))
    }

    /// Style Library Apply: the selected Script scene gets the style.
    func useStyle(_ name: String) {
        guard case .script(let scene) = selectedItem else { notice = Notice(text: localized("pickScript")); return }
        setStyle(name, of: scene.id)
    }

    /// Expression Library Apply: changes the selected expression; with a Script selected, inserts one after it.
    func applyExpression(_ tag: ExpressionTag) {
        if case .expr(let scene) = selectedItem { setExpression(tag, of: scene.id) } else { addExpression(tag) }
    }

    func label(_ tag: ExpressionTag) -> String { localized("ex." + tag.key) }

    private func update(_ id: String, _ change: (inout ScriptScene) -> Void) {
        guard let at = items.firstIndex(where: { $0.id == id }), case .script(var scene) = items[at] else { return }
        change(&scene)
        draft.items[at] = .script(scene)
    }
}
