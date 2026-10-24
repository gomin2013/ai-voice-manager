import Foundation
import Observation

/// The open window's state: every project, the open one, its History and its takes. Views call these methods and
/// never change the draft themselves; the rules live in Models (segments, assignVoice, clean). With a `store`,
/// every History step also saves the project (autosave); without one (tests, previews) it stays in memory.
@MainActor
@Observable
final class EditorViewModel {
    private(set) var projects: [Project]
    private(set) var currentID: String
    private(set) var histories: [String: ProjectHistory<ProjectDraft>] = [:]
    /// History › Scene, per project id (`EditorViewModel+SceneHistory`).
    var sceneHistories: [String: SceneHistory] = [:]
    /// A short message under the toolbar ("Select a script scene first", the two-voice refusal …), with an optional
    /// Undo. The view shows it and clears it.
    var notice: Notice?
    private(set) var isGenerating = false
    /// New Project opens with its name ready to type over; the header picks this up and clears it.
    var renameRequested = false
    /// ⌘↵: GeneratePanel takes it from here, so a paid take is confirmed the same way as with the button.
    var generateRequested = false
    /// Scene previews: ready while the scene's signature is unchanged (prototype `pvSig`). In memory only — a
    /// preview is cheap to make again and never part of a take.
    private(set) var scenePreviews: [String: ScenePreview] = [:]
    private(set) var previewBusy: String?
    /// The Script scene Ollama is rewriting (Polish / Add pauses) — set by `EditorViewModel+Ollama`.
    var aiBusy: String?
    /// A Gemini key is in the Keychain (the key itself is read from there only when a request goes out).
    private(set) var hasGeminiKey: Bool

    struct ScenePreview {
        let signature: String
        let duration: Double
        let audio: Data
        let heights: [Double]?
    }

    struct Notice: Identifiable {
        let id = UUID()
        let text: String
        var undo: (@MainActor () -> Void)?
    }

    let store: ProjectStore?
    /// Tests swap in a stubbed session and key; the app talks to Google with the Keychain's key.
    @ObservationIgnored var session = URLSession.shared
    @ObservationIgnored var loadKey: () -> String? = KeychainStore.load
    @ObservationIgnored private var waveforms: [String: [Double]] = [:]
    /// The AI Agent's answer for Polish / Add pauses (settings, system, turns) — tests swap in a canned one.
    @ObservationIgnored var askAI: (AISettings, String, [ChatTurn]) async throws -> String = {
        try await AIService.complete($0, system: $1, turns: $2)
    }

    init(projects: [Project] = MockData.projects(), hasGeminiKey: Bool = KeychainStore.load() != nil,
         store: ProjectStore? = nil) {
        precondition(!projects.isEmpty, "the window always has a project")
        self.projects = projects
        self.hasGeminiKey = hasGeminiKey
        self.store = store
        currentID = projects[0].id
        openHistory()
    }

    /// The app's start: every saved project, newest opened first. The very first launch writes the demo projects
    /// (without their mock takes) so the window isn't empty.
    static func launch(store: ProjectStore = .standard) -> EditorViewModel {
        var projects = store.loadAll()
        if projects.isEmpty {
            projects = MockData.projects().map {
                Project(id: UUID().uuidString, opened: $0.opened, draft: $0.draft, takes: [], selection: nil)
            }
            for project in projects { try? store.save(project) }
        }
        return EditorViewModel(projects: projects, store: store)
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

    /// After an edit: one History step, labelled by what changed — and the project is saved.
    func record(_ label: String) {
        histories[currentID, default: history].record(label, snapshot: draft)
        save(project)
    }

    /// Autosave: `project.json` only (takes are written once, when generated).
    func save(_ project: Project) {
        guard let store else { return }
        do { try store.save(project) } catch { notice = Notice(text: localized("saveFailed", project.draft.title)) }
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
        save(project)
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
        switchProject(to: project.id)   // saves it
    }

    /// Its folder goes to the Trash; Undo brings it back. The last project can't go: the window needs one.
    func removeProject(_ id: String) {
        guard projects.count > 1, let at = projects.firstIndex(where: { $0.id == id }) else { return }
        let trashed: URL?
        do { trashed = try store?.trash(id) } catch {
            notice = Notice(text: localized("trashFailed", projects[at].draft.title))
            return
        }
        let removed = projects.remove(at: at)
        if id == currentID {
            currentID = recentProjects[0].id
            openHistory()
        }
        notice = Notice(text: localized("removed", removed.draft.title)) { [weak self] in
            guard let self else { return }
            if let trashed { try? store?.restore(id, from: trashed) }
            projects.insert(removed, at: min(at, projects.count))
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

    func pinCurrent() { pin(draft) }

    /// History › right-click › Pin This Version: any step, named like Pin Current Version (Hosts Manager).
    func pin(_ stepID: UUID) { if let step = history.step(stepID) { pin(step.snapshot) } }

    private func pin(_ snapshot: ProjectDraft) {
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        histories[currentID, default: history].pin(localized("hist.pinDefault", time), snapshot: snapshot)
    }

    func renamePin(_ id: UUID, to label: String) { histories[currentID, default: history].renamePin(id, to: label) }
    func unpin(_ id: UUID) { histories[currentID, default: history].unpin(id) }
    func removeStep(_ id: UUID) { histories[currentID, default: history].removeStep(id) }

    // MARK: - Google key (AI Providers): one key for every project, in the Keychain

    /// Save (trimmed; empty = nothing to save). Returns false if the Keychain refused.
    @discardableResult
    func saveGeminiKey(_ key: String) -> Bool {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        guard KeychainStore.save(key) else { notice = Notice(text: localized("keyFailed")); return false }
        hasGeminiKey = true
        notice = Notice(text: localized("keySaved"))
        return true
    }

    /// Remove, with Undo (the key comes back into the Keychain).
    func removeGeminiKey() {
        guard let old = KeychainStore.load() else { return }
        KeychainStore.remove()
        hasGeminiKey = false
        notice = Notice(text: localized("keyRemoved")) { [weak self] in
            if KeychainStore.save(old) { self?.hasGeminiKey = true }
        }
    }

    /// Test connection → the line shown under the buttons.
    func testGeminiKey() async -> String {
        guard let key = KeychainStore.load() else { return "" }
        do {
            try await GeminiTTS.testKey(key)
            return "✓ " + localized("testOk")
        } catch let failure as GeminiTTS.Failure {
            return "✗ " + failure.text
        } catch {
            return "✗ " + error.localizedDescription
        }
    }

    // MARK: - Generate

    /// Gemini TTS with the Keychain key, or nil after telling the user why not.
    private func geminiKey() -> String? {
        guard let key = loadKey() else {
            hasGeminiKey = false
            notice = Notice(text: localized("needKey"))
            return nil
        }
        return key
    }

    /// Whole project only (ADR-009) → `Takes/<id>/take.wav` + `take.json`. A failure leaves no take behind.
    func generate() async {
        guard !isGenerating else { return }
        guard !segments(of: draft).isEmpty else { notice = Notice(text: localized("nothing")); return }
        guard let key = geminiKey() else { return }
        let projectID = currentID, snapshot = draft
        isGenerating = true
        defer { isGenerating = false }
        do {
            let wav = try await GeminiTTS.generate(snapshot, key: key, session: session)
            // The user may have switched (or removed) the project meanwhile: the take belongs to the one generated
            guard let at = projects.firstIndex(where: { $0.id == projectID }) else { return }
            let created = Date.now
            let take = Take(id: store?.newTakeID(at: created, in: projectID) ?? UUID().uuidString, created: created,
                            duration: wavDuration(wav) ?? estimateSeconds(plainText(of: snapshot)),
                            draft: snapshot, mock: false)
            try store?.saveTake(take, wav: wav, in: projectID)
            projects[at].takes.insert(take, at: 0)
            notice = Notice(text: localized("saved"))
        } catch {
            notice = Notice(text: message(for: error))
        }
    }

    func message(for error: Error) -> String {
        (error as? GeminiTTS.Failure)?.text ?? error.localizedDescription
    }

    /// A take's bars, read from its WAV once and kept while the app runs (a take never changes).
    func waveform(of take: Take) -> [Double]? {
        if let cached = waveforms[take.id] { return cached }
        guard let url = audio(of: take), let wav = try? Data(contentsOf: url), let heights = waveHeights(wav)
        else { return nil }
        waveforms[take.id] = heights
        return heights
    }

    /// The take's WAV on disk, nil for a mock take (or without a store).
    func audio(of take: Take) -> URL? {
        guard !take.mock, let url = store?.audio(of: take.id, in: currentID),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The take's timeline comes back (fresh scene ids, the project keeps its name) as one History step.
    func restoreTake(_ id: String) {
        guard let take = project.takes.first(where: { $0.id == id }) else { return }
        draft = ProjectDraft(title: draft.title, model: take.draft.model, speakers: take.draft.speakers,
                             items: take.draft.items.map(\.withFreshID))
        project.selection = nil
        record(localized("hist.take", Duration.seconds(take.duration).formatted(.time(pattern: .minuteSecond))))
    }

    /// The take's folder goes to the Trash; Undo brings it back.
    func deleteTake(_ id: String) {
        let projectID = currentID
        guard let at = project.takes.firstIndex(where: { $0.id == id }) else { return }
        var trashed: URL?
        if !project.takes[at].mock, let store,
           FileManager.default.fileExists(atPath: store.takeFolder(id, of: projectID).path) {
            do { trashed = try store.trashTake(id, of: projectID) } catch {
                notice = Notice(text: localized("trashFailed", id))
                return
            }
        }
        let take = project.takes.remove(at: at)
        notice = Notice(text: localized("deleted")) { [weak self] in
            guard let self, let owner = projects.firstIndex(where: { $0.id == projectID }) else { return }
            if let trashed { try? store?.restoreTake(id, of: projectID, from: trashed) }
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

    /// The scene's preview while it still matches the scene (any edit makes it stale).
    func readyPreview(of scene: ScriptScene) -> ScenePreview? {
        scenePreviews[scene.id].flatMap { $0.signature == previewSignature(of: scene) ? $0 : nil }
    }

    /// Generate preview: this one scene alone, same model and voice as the take.
    func generatePreview(of scene: ScriptScene) async {
        guard previewBusy == nil else { return }
        guard !scene.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = Notice(text: localized("nothing"))
            return
        }
        guard let key = geminiKey() else { return }
        previewBusy = scene.id
        defer { previewBusy = nil }
        let signature = previewSignature(of: scene)
        let one = ProjectDraft(title: draft.title, model: draft.model, speakers: draft.speakers,
                               items: [.script(scene)])
        do {
            let wav = try await GeminiTTS.generate(one, key: key, session: session)
            let duration = wavDuration(wav) ?? estimateSeconds(scene.text)
            scenePreviews[scene.id] = ScenePreview(signature: signature, duration: duration, audio: wav,
                                                   heights: waveHeights(wav))
        } catch {
            notice = Notice(text: message(for: error))
        }
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
