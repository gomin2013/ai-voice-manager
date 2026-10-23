import Foundation
import Observation

/// The open window's state: every project, the open one, its History and its takes. Views call these methods and
/// never change the draft themselves; the rules live in Models (segments, assignVoice, clean). Phase 2: in memory
/// on `MockData` — Phase 3 adds ProjectStore underneath, same methods.
@MainActor
@Observable
final class EditorViewModel {
    private(set) var projects: [Project]
    private(set) var currentID: String
    private(set) var histories: [String: ProjectHistory<ProjectDraft>] = [:]
    /// A short message under the toolbar ("Select a script scene first", the two-voice refusal …), with an optional
    /// Undo. The view shows it and clears it.
    var notice: Notice?
    private(set) var isGenerating = false
    /// New Project opens with its name ready to type over; the header picks this up and clears it.
    var renameRequested = false
    /// ⌘↵: GeneratePanel takes it from here, so a paid take is confirmed the same way as with the button.
    var generateRequested = false
    /// Scene previews (mock until Phase 3): ready while the scene's signature is unchanged (prototype `pvSig`).
    private(set) var scenePreviews: [String: (signature: String, duration: Double)] = [:]
    private(set) var previewBusy: String?

    struct Notice: Identifiable {
        let id = UUID()
        let text: String
        var undo: (@MainActor () -> Void)?
    }

    init(projects: [Project] = MockData.projects()) {
        precondition(!projects.isEmpty, "the window always has a project")
        self.projects = projects
        currentID = projects[0].id
        openHistory()
    }

    // MARK: - The open project

    private var index: Int { projects.firstIndex { $0.id == currentID } ?? 0 }

    var project: Project {
        get { projects[index] }
        set { projects[index] = newValue }
    }

    var draft: ProjectDraft {
        get { project.draft }
        set { project.draft = newValue }
    }

    var history: ProjectHistory<ProjectDraft> {
        histories[currentID] ?? ProjectHistory(opened: draft, label: localized("hist.opened"))
    }

    var model: TTSModel { ModelCatalog.model(draft.model) }

    /// Recent Projects order: last opened first.
    var recentProjects: [Project] { projects.sorted { $0.opened > $1.opened } }

    /// After an edit: one History step, labelled by what changed. Autosave hooks in here in Phase 3.
    func record(_ label: String) {
        histories[currentID, default: history].record(label, snapshot: draft)
    }

    private func openHistory() {
        if histories[currentID] == nil {
            histories[currentID] = ProjectHistory(opened: draft, label: localized("hist.opened"))
        }
    }

    // MARK: - Projects

    func switchProject(to id: String) {
        guard id != currentID, projects.contains(where: { $0.id == id }) else { return }
        currentID = id
        project.opened = .now
        openHistory()
    }

    /// New Project (after the model sheet): starts as "Untitled project" with one empty Script scene.
    func newProject(model: String) {
        let draft = ProjectDraft(title: localized("untitled"), model: model, speakers: draft.speakers,
                                 items: [.script(ScriptScene())])
        add(draft)
        renameRequested = true
    }

    /// Open Project…: a cleaned import (clean(imported:)) becomes a new project.
    func add(_ draft: ProjectDraft, takes: [Take] = []) {
        let project = Project(id: UUID().uuidString, opened: .now, draft: draft, takes: takes, selection: nil)
        projects.append(project)
        switchProject(to: project.id)
    }

    /// Forgets the entry only (the files stay — Phase 3). The last project can't go: the window needs one.
    func removeProject(_ id: String) {
        guard projects.count > 1, let at = projects.firstIndex(where: { $0.id == id }) else { return }
        let removed = projects.remove(at: at)
        if id == currentID {
            currentID = recentProjects[0].id
            openHistory()
        }
        notice = Notice(text: localized("removed", removed.draft.title)) { [weak self] in
            self?.projects.insert(removed, at: min(at, self?.projects.count ?? 0))
        }
    }

    /// Rename: trimmed, never empty (returns false and changes nothing), max 200 like imports.
    @discardableResult
    func rename(_ title: String) -> Bool {
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !title.isEmpty else { return false }
        guard title != draft.title else { return true }
        draft.title = title
        record(localized("hist.title"))
        return true
    }

    func setModel(_ id: String) {
        guard id != draft.model, ModelCatalog.all.contains(where: { $0.id == id }) else { return }
        draft.model = id
        record(localized("hist.model", model.name.replacingOccurrences(of: "Gemini ", with: "")))
    }

    // MARK: - History

    /// ↩ or double-click: the step's project comes back as a **new** step.
    func restore(_ stepID: UUID) {
        guard let step = history.step(stepID), step.id != history.current?.id else { return }
        let isPin = history.pinned.contains { $0.id == stepID }
        draft = step.snapshot
        project.selection = nil
        let time = step.date.formatted(date: .omitted, time: .shortened)
        record(!isPin ? localized("hist.reverted", time)
               : step.isOpened ? localized("hist.revertedOpened") : localized("hist.restored", step.label))
    }

    func pinCurrent() {
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        histories[currentID, default: history].pin(localized("hist.pinDefault", time), snapshot: draft)
    }

    func renamePin(_ id: UUID, to label: String) { histories[currentID, default: history].renamePin(id, to: label) }
    func unpin(_ id: UUID) { histories[currentID, default: history].unpin(id) }
    func removeStep(_ id: UUID) { histories[currentID, default: history].removeStep(id) }

    // MARK: - Generate (mock until Phase 3)

    /// Whole project only (ADR-009). Mock: waits like a request, then keeps a take marked MOCK.
    func generate() async {
        guard !isGenerating else { return }
        guard !segments(of: draft).isEmpty else { notice = Notice(text: localized("nothing")); return }
        let projectID = currentID, snapshot = draft
        isGenerating = true
        defer { isGenerating = false }
        try? await Task.sleep(for: .milliseconds(1400))
        // The user may have switched project meanwhile: the take belongs to the one that was generated
        guard let at = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let take = Take(id: UUID().uuidString, created: .now, duration: estimateSeconds(plainText(of: snapshot)),
                        draft: snapshot, mock: true)
        projects[at].takes.insert(take, at: 0)
        notice = Notice(text: localized("saved"))
    }

    /// The take's timeline comes back (fresh scene ids, the project keeps its name) as one History step.
    func restoreTake(_ id: String) {
        guard let take = project.takes.first(where: { $0.id == id }) else { return }
        draft = ProjectDraft(title: draft.title, model: take.draft.model, speakers: take.draft.speakers,
                             items: take.draft.items.map(\.withFreshID))
        project.selection = nil
        record(localized("hist.take", Duration.seconds(take.duration).formatted(.time(pattern: .minuteSecond))))
    }

    func deleteTake(_ id: String) {
        let projectID = currentID
        guard let at = project.takes.firstIndex(where: { $0.id == id }) else { return }
        let take = project.takes.remove(at: at)
        notice = Notice(text: localized("deleted")) { [weak self] in
            guard let self, let owner = projects.firstIndex(where: { $0.id == projectID }) else { return }
            projects[owner].takes.insert(take, at: min(at, projects[owner].takes.count))
        }
    }
}

extension EditorViewModel {
    /// Any change to the text, speaker, style, that speaker's voice or the model makes a preview stale.
    func previewSignature(of scene: ScriptScene) -> String {
        [scene.text, scene.speaker.rawValue, scene.style, draft.speaker(scene.speaker).voice, draft.model]
            .joined(separator: "\u{1F}")
    }

    func readyPreview(of scene: ScriptScene) -> Double? {
        scenePreviews[scene.id].flatMap { $0.signature == previewSignature(of: scene) ? $0.duration : nil }
    }

    /// Generate preview: this one scene, same model and voice as the take. Mock: waits, then it's Ready.
    func generatePreview(of scene: ScriptScene) async {
        guard previewBusy == nil else { return }
        previewBusy = scene.id
        defer { previewBusy = nil }
        try? await Task.sleep(for: .milliseconds(900))
        scenePreviews[scene.id] = (previewSignature(of: scene), estimateSeconds(scene.text))
    }
}

extension TimelineItem {
    var withFreshID: TimelineItem {
        switch self {
        case .script(var scene): scene.id = newSceneID(); return .script(scene)
        case .expr(var scene): scene.id = newSceneID(); return .expr(scene)
        }
    }
}
