import XCTest
@testable import AIVoiceManagerApp

/// The alert table — same cases as the prototype's `netNext`.
final class ConnectionMonitorTests: XCTestCase {
    private typealias Monitor = ConnectionMonitor
    private let fast = Monitor.State(online: true, speed: .fast), slow = Monitor.State(online: true, speed: .slow)
    private let offline = Monitor.State(online: false, speed: .unknown)

    func testOfflineAndBack() {
        XCTAssertEqual(Monitor.next(fast, .path(online: false)).1, .offline)
        XCTAssertEqual(Monitor.next(offline, .path(online: true)).1, .restored)
        XCTAssertEqual(Monitor.next(offline, .path(online: true)).0, Monitor.State(online: true, speed: .unknown))
        XCTAssertNil(Monitor.next(fast, .path(online: true)).1)       // nothing changed: no alert
        XCTAssertNil(Monitor.next(offline, .path(online: false)).1)
    }

    func testSlowOnceThenFastAgainOnlyAfterSlow() {
        XCTAssertEqual(Monitor.next(fast, .measured(ms: 2_300)).1, .slow)
        XCTAssertNil(Monitor.next(slow, .measured(ms: 2_300)).1)       // already slow: no repeat
        XCTAssertEqual(Monitor.next(slow, .measured(ms: 300)).1, .fast)
        XCTAssertNil(Monitor.next(fast, .measured(ms: 300)).1)         // fast without a slow before: quiet
        XCTAssertEqual(Monitor.next(fast, .measured(ms: nil)).1, .slow) // no answer in 8 s counts as slow
    }

    func testTheGapBetweenThresholdsChangesNothing() {
        XCTAssertNil(Monitor.next(slow, .measured(ms: 1_000)).1)
        XCTAssertEqual(Monitor.next(slow, .measured(ms: 1_000)).0, slow)
        XCTAssertNil(Monitor.next(offline, .measured(ms: 99)).1)       // measurements while offline are ignored
    }
}
