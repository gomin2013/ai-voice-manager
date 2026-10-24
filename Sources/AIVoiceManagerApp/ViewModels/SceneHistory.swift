import Foundation

/// One Scene History row: a scene's text as it was at that point.
struct SceneEdit: Identifiable, Equatable, Sendable {
    let id = UUID()
    let sceneID: String
    let label: String
    let date: Date
    let text: String
}

/// History › Scene: text versions of the Script scenes, the last 30 per project (History › Script keeps its own 30
/// project-wide steps). A step here holds one scene's text, not the whole project, so going back to it changes only
/// that scene — never the timeline edits made since. The first edit of a scene also keeps the text it started from.
struct SceneHistory: Equatable, Sendable {
    static var limit: Int { 30 }

    /// Oldest first.
    private(set) var edits: [SceneEdit] = []

    /// The scene's newest text here, or nil if it was never edited.
    func lastText(of sceneID: String) -> String? { edits.last { $0.sceneID == sceneID }?.text }

    /// The newest row of each scene is that scene's "Now".
    func isCurrent(_ edit: SceneEdit) -> Bool { edits.last { $0.sceneID == edit.sceneID }?.id == edit.id }

    /// `before` is kept first (as `beforeLabel`) when this scene has no row yet, so deleted text can come back.
    mutating func record(sceneID: String, label: String, text: String, before: String, beforeLabel: String,
                         date: Date = .now) {
        if lastText(of: sceneID) == nil {
            edits.append(SceneEdit(sceneID: sceneID, label: beforeLabel, date: date, text: before))
        }
        edits.append(SceneEdit(sceneID: sceneID, label: label, date: date, text: text))
        if edits.count > Self.limit { edits.removeFirst(edits.count - Self.limit) }
    }

    func edit(_ id: UUID) -> SceneEdit? { edits.first { $0.id == id } }

    /// Any row but a scene's "Now" (you're standing on it).
    mutating func remove(_ id: UUID) {
        guard let edit = edit(id), !isCurrent(edit) else { return }
        edits.removeAll { $0.id == id }
    }
}
