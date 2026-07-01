import XCTest
@testable import OrcaCore

private final class NotificationSpy: NotificationScheduling {
    private(set) var scheduled: [(title: String, body: String, sound: Bool)] = []
    func schedule(title: String, body: String, sound: Bool) { scheduled.append((title, body, sound)) }
}

final class SessionHealthTests: XCTestCase {
    private var currentTime = Date(timeIntervalSince1970: 10_000)
    private var transcriptMTime: Date?
    private var alivePIDs: Set<Int32> = []

    private func makeStore(spy: NotificationSpy = NotificationSpy()) -> AgentStore {
        AgentStore(
            notifications: spy,
            now: { self.currentTime },
            transcriptActivity: { _ in self.transcriptMTime },
            processAlive: { self.alivePIDs.contains($0) },
            waitingConfirmDelay: 6,
            activityWindow: 30
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

    func testWaitingWithActiveTranscriptRevivesToRunning() {
        let store = makeStore()
        alivePIDs = [42]
        store.apply(claudeEvent("waiting", pid: 42))
        XCTAssertEqual(store.agents.first?.status, .waiting)

        // Transcript written well after the stop event: Claude auto-resumed.
        transcriptMTime = currentTime.addingTimeInterval(5)
        currentTime = currentTime.addingTimeInterval(8)
        store.evaluateHealth()

        XCTAssertEqual(store.agents.first?.status, .running)
        XCTAssertEqual(store.agents.first?.message, "Working…")
    }

    func testQuietTranscriptDoesNotRevive() {
        let store = makeStore()
        alivePIDs = [42]
        transcriptMTime = currentTime.addingTimeInterval(-1)
        store.apply(claudeEvent("waiting", pid: 42))
        currentTime = currentTime.addingTimeInterval(10)
        store.evaluateHealth()
        XCTAssertEqual(store.agents.first?.status, .waiting)
    }

    func testWaitingNotificationIsDebouncedUntilQuiet() {
        let spy = NotificationSpy()
        let store = makeStore(spy: spy)
        alivePIDs = [42]
        transcriptMTime = currentTime.addingTimeInterval(-1)

        store.apply(claudeEvent("waiting", pid: 42))
        XCTAssertTrue(spy.scheduled.isEmpty)

        currentTime = currentTime.addingTimeInterval(3)
        store.evaluateHealth()
        XCTAssertTrue(spy.scheduled.isEmpty)

        currentTime = currentTime.addingTimeInterval(4)
        store.evaluateHealth()
        XCTAssertEqual(spy.scheduled.count, 1)

        store.evaluateHealth()
        XCTAssertEqual(spy.scheduled.count, 1)
    }

    func testAutoResumeCancelsPendingNotification() {
        let spy = NotificationSpy()
        let store = makeStore(spy: spy)
        alivePIDs = [42]
        store.apply(claudeEvent("waiting", pid: 42))

        transcriptMTime = currentTime.addingTimeInterval(4)
        currentTime = currentTime.addingTimeInterval(7)
        store.evaluateHealth()

        XCTAssertEqual(store.agents.first?.status, .running)
        XCTAssertTrue(spy.scheduled.isEmpty)

        currentTime = currentTime.addingTimeInterval(60)
        store.evaluateHealth()
        XCTAssertTrue(spy.scheduled.isEmpty)
    }

    func testNonTranscriptSourcesNotifyImmediately() {
        let spy = NotificationSpy()
        let store = makeStore(spy: spy)
        store.apply(AgentEvent(id: "c1", source: "custom", title: "job", cwd: "/p", status: "waiting"))
        XCTAssertEqual(spy.scheduled.count, 1)
    }
}
