import Foundation

/// One History row: what was done, when, and the whole project as it was after.
struct HistoryStep<Snapshot: Equatable & Sendable>: Identifiable, Equatable, Sendable {
    let id: UUID
    var label: String
    let date: Date
    let snapshot: Snapshot
    /// The "When Opened" pin: can't be renamed or unpinned.
    var isOpened = false

    init(label: String, date: Date = .now, snapshot: Snapshot, isOpened: Bool = false) {
        id = UUID()
        self.label = label
        self.date = date
        self.snapshot = snapshot
        self.isOpened = isOpened
    }
}

/// History like Hosts Manager (ADR-008, prototype shell.js): Recent = the last 30 steps, the newest is "Now"; going
/// back is a **new** step, so nothing is lost. Pinned = your pins (newest first), then "When Opened".
/// One per project, in memory while the app runs (persisting it is a Phase 3 question).
struct ProjectHistory<Snapshot: Equatable & Sendable>: Equatable, Sendable {
    static var limit: Int { 30 }

    /// Oldest first; `last` is the current state.
    private(set) var steps: [HistoryStep<Snapshot>]
    private(set) var pinned: [HistoryStep<Snapshot>]

    init(opened snapshot: Snapshot, label: String, date: Date = .now) {
        steps = [HistoryStep(label: label, date: date, snapshot: snapshot)]
        pinned = [HistoryStep(label: label, date: date, snapshot: snapshot, isOpened: true)]
    }

    var current: HistoryStep<Snapshot>? { steps.last }

    mutating func record(_ label: String, snapshot: Snapshot, date: Date = .now) {
        steps.append(HistoryStep(label: label, date: date, snapshot: snapshot))
        if steps.count > Self.limit { steps.removeFirst(steps.count - Self.limit) }
    }

    /// A step or pin by id — the caller applies its snapshot, then records the restore as a new step.
    func step(_ id: UUID) -> HistoryStep<Snapshot>? {
        steps.first { $0.id == id } ?? pinned.first { $0.id == id }
    }

    mutating func pin(_ label: String, snapshot: Snapshot, date: Date = .now) {
        pinned.insert(HistoryStep(label: label, date: date, snapshot: snapshot), at: 0)
    }

    mutating func renamePin(_ id: UUID, to label: String) {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, let index = pinned.firstIndex(where: { $0.id == id && !$0.isOpened }) else { return }
        pinned[index].label = label
    }

    mutating func unpin(_ id: UUID) { pinned.removeAll { $0.id == id && !$0.isOpened } }

    /// Any past step; never the current one (you're standing on it).
    mutating func removeStep(_ id: UUID) {
        guard id != current?.id else { return }
        steps.removeAll { $0.id == id }
    }
}
