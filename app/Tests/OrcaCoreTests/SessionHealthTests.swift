import XCTest
@testable import OrcaCore

private final class NotificationSpy: NotificationScheduling {
    private(set) var scheduled: [(title: String, body: String, sound: Bool)] = []
    func schedule(title: String, body: String, sound: Bool) { scheduled.append((title, body, sound)) }
}

final class SessionHealthTests: XCTestCase {
    private var currentTime = Date(timeIntervalSince1970: 10_000)
    private var alivePIDs: Set<Int32> = []

    private func makeStore(spy: NotificationSpy = NotificationSpy()) -> AgentStore {
        AgentStore(
            notifications: spy,
            now: { self.currentTime },
            processAlive: { self.alivePIDs.contains($0) }
        )
    }

    private func claudeEvent(_ status: String, pid: Int32? = nil) -> AgentEvent {
        AgentEvent(id: "s1", source: "claude-code", title: "proj", cwd: "/p",
                   status: status, transcriptPath: "/t/x.jsonl", pid: pid)
    }

    func testDeadProcessRemovesAgent() {
        let store = makeStore()
        alivePIDs = [42]
        store.apply(claudeEvent("running", pid: 42))
        XCTAssertEqual(store.agents.count, 1)

        alivePIDs = []
        store.evaluateHealth()
        XCTAssertTrue(store.agents.isEmpty)
    }

    func testStatusIsExactlyWhatHooksReport() {
        let store = makeStore()
        alivePIDs = [42]
        store.apply(claudeEvent("waiting", pid: 42))
        XCTAssertEqual(store.agents.first?.status, .waiting)

        // Long silence changes nothing — only hook events move state.
        currentTime = currentTime.addingTimeInterval(3600)
        store.evaluateHealth()
        XCTAssertEqual(store.agents.first?.status, .waiting)

        store.apply(claudeEvent("running", pid: 42))
        XCTAssertEqual(store.agents.first?.status, .running)
    }

    func testWaitingNotifiesImmediatelyOnTransition() {
        let spy = NotificationSpy()
        let store = makeStore(spy: spy)
        alivePIDs = [42]
        store.apply(claudeEvent("running", pid: 42))
        XCTAssertTrue(spy.scheduled.isEmpty)
        store.apply(claudeEvent("waiting", pid: 42))
        XCTAssertEqual(spy.scheduled.count, 1)
        store.apply(claudeEvent("waiting", pid: 42))
        XCTAssertEqual(spy.scheduled.count, 1)
    }

    func testLivePidSurvivesStaleTTLPrune() {
        let store = makeStore()
        alivePIDs = [42]
        store.apply(claudeEvent("waiting", pid: 42))
        store.prune(now: currentTime.addingTimeInterval(7200))
        XCTAssertEqual(store.agents.count, 1)
    }
}
