import Foundation

/// History › Scene: the Script scenes' text versions (`SceneHistory`), next to History › Script's project steps.
extension EditorViewModel {
    var sceneHistory: SceneHistory { sceneHistories[currentID] ?? SceneHistory() }

    /// Records the scene's text if it changed since its last row (or since the last Script step, for a first edit).
    func recordSceneText(of id: String) {
        guard let text = Self.text(of: id, in: draft) else { return }
        let before = sceneHistory.lastText(of: id) ?? history.current.flatMap { Self.text(of: id, in: $0.snapshot) }
        guard let before, text != before else { return }
        let number = "\(sceneNumber(id))"
        sceneHistories[currentID, default: SceneHistory()].record(
            sceneID: id, label: localized("hist.edit", number), text: text,
            before: before, beforeLabel: localized("hist.sceneBefore", number))
        save(project)
    }

    /// ↩ / double-click a Scene row: only that scene's text comes back — as a new row, so nothing is lost.
    func restoreSceneText(_ editID: UUID) {
        guard let edit = sceneHistory.edit(editID), !sceneHistory.isCurrent(edit),
              Self.text(of: edit.sceneID, in: draft) != nil else { return }
        setText(edit.text, of: edit.sceneID)
        sceneHistories[currentID, default: SceneHistory()].record(
            sceneID: edit.sceneID, label: localized("hist.restored", edit.label), text: edit.text,
            before: edit.text, beforeLabel: edit.label)
        save(project)
    }

    func removeSceneEdit(_ id: UUID) { sceneHistories[currentID, default: SceneHistory()].remove(id) }

    /// A Script scene's text in a project version; nil for an Expression or a scene that isn't there.
    static func text(of id: String, in draft: ProjectDraft) -> String? {
        guard case .script(let scene)? = draft.items.first(where: { $0.id == id }) else { return nil }
        return scene.text
    }
}
