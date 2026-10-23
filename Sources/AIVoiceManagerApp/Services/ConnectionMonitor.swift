import Foundation
import Network
import Observation

/// This app needs the internet for Gemini, so it says when the connection is gone, back, slow or fast again
/// (prototype `Net`). Online / offline = `NWPathMonitor`; speed = how long a tiny request to Google takes, on every
/// change and every 60 s.
@MainActor
@Observable
final class ConnectionMonitor {
    enum Speed: Equatable, Sendable { case unknown, fast, slow }
    struct State: Equatable, Sendable { var online = true, speed = Speed.unknown }
    enum Event: Equatable, Sendable { case path(online: Bool), measured(ms: Double?) }   // nil ms = no answer
    enum Alert: Equatable, Sendable { case offline, restored, slow, fast }

    nonisolated static let slowMS = 1_500.0, fastMS = 800.0, timeout = 8.0
    nonisolated static let probe = URL(string: "https://generativelanguage.googleapis.com/")!

    /// Pure: what an event does to the state, and the alert to show (`.some(nil)` never happens: nil = keep).
    /// The gap between `fastMS` and `slowMS` keeps the alert from flickering around one threshold.
    nonisolated static func next(_ state: State, _ event: Event) -> (State, Alert?) {
        switch event {
        case .path(let online):
            if online == state.online { return (state, nil) }
            return (State(online: online, speed: .unknown), online ? .restored : .offline)
        case .measured(let ms):
            guard state.online else { return (state, nil) }
            let slow = ms.map { $0 > slowMS } ?? true, fast = ms.map { $0 < fastMS } ?? false
            if slow && state.speed != .slow { return (State(online: true, speed: .slow), .slow) }
            if fast && state.speed == .slow { return (State(online: true, speed: .fast), .fast) }
            return (fast ? State(online: true, speed: .fast) : state, nil)
        }
    }

    private(set) var state = State()
    private(set) var alert: Alert?
    private(set) var lastMS = 0.0
    var isOnline: Bool { state.online }

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var hide: Task<Void, Never>?

    func start() {
        guard tasks.isEmpty else { return }
        let paths = AsyncStream<Bool> { continuation in
            monitor.pathUpdateHandler = { continuation.yield($0.status == .satisfied) }
            monitor.start(queue: DispatchQueue(label: "ConnectionMonitor"))
        }
        tasks.append(Task { [weak self] in
            for await online in paths { await self?.handle(.path(online: online)) }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self?.measure()
            }
        })
    }

    func dismiss() { show(nil) }

    private func handle(_ event: Event) async {
        let (next, newAlert) = Self.next(state, event)
        state = next
        if let newAlert { show(newAlert) }
        if case .path(true) = event { await measure() }
    }

    /// Time to Google's API host: any HTTP answer counts (no key needed — a 404 is still a round trip).
    private func measure() async {
        guard state.online else { return }
        var request = URLRequest(url: Self.probe)
        request.httpMethod = "HEAD"
        request.timeoutInterval = Self.timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let start = ContinuousClock.now
        let answered = (try? await URLSession.shared.data(for: request)) != nil
        let ms = (ContinuousClock.now - start) / .milliseconds(1)
        if answered { lastMS = ms }
        let (next, newAlert) = Self.next(state, .measured(ms: answered ? ms : nil))
        state = next
        if let newAlert { show(newAlert) }
    }

    /// Offline and slow stay until things change (slow can be closed); restored and fast go after 5 s.
    private func show(_ newAlert: Alert?) {
        hide?.cancel()
        alert = newAlert
        guard newAlert == .restored || newAlert == .fast else { return }
        hide = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { self?.alert = nil }
        }
    }
}
