import XCTest
@testable import OrcaCore

private final class NotificationSpy: NotificationScheduling {
    private(set) var scheduled: [(title: String, body: String, sound: Bool)] = []
    func schedule(title: String, body: String, sound: Bool) { scheduled.append((title, body, sound)) }
}

private final class Clock {
    var current: Date
    init(_ start: Date) { current = start }
    func advance(_ seconds: TimeInterval) { current += seconds }
    var provider: () -> Date { { [self] in current } }
}

final class AgentStoreTests: XCTestCase {
    private func event(_ id: String, _ status: String, source: String = "claude-code", title: String = "proj") -> AgentEvent {
        AgentEvent(id: id, source: source, title: title, cwd: "/proj", status: status)
    }

    func testRunningThenWaitingFreezesDuration() {
        let clock = Clock(Date(timeIntervalSince1970: 1000))
        let store = AgentStore(notifications: NotificationSpy(), now: clock.provider)

        store.apply(event("a", "running"))
        clock.advance(5)
        XCTAssertEqual(store.agents.first!.duration(now: clock.current), 5, accuracy: 0.001)

        store.apply(event("a", "waiting"))
        clock.advance(100)
        XCTAssertEqual(store.agents.first!.duration(now: clock.current), 5, accuracy: 0.001)
    }

    func testNewRunResetsDuration() {
        let clock = Clock(Date(timeIntervalSince1970: 0))
        let store = AgentStore(notifications: NotificationSpy(), now: clock.provider)
        store.apply(event("a", "running"))
        clock.advance(10)
        store.apply(event("a", "waiting"))
        store.apply(event("a", "running"))
        clock.advance(3)
        XCTAssertEqual(store.agents.first!.duration(now: clock.current), 3, accuracy: 0.001)
    }

    func testRunningAndOpenCounts() {
        let store = AgentStore(notifications: NotificationSpy())
        store.apply(event("a", "running"))
        store.apply(event("b", "running"))
        store.apply(event("c", "waiting"))
        XCTAssertEqual(store.runningCount, 2)
        XCTAssertEqual(store.openSessionCount, 3)

        store.apply(event("b", "done"))
        XCTAssertEqual(store.runningCount, 1)
        XCTAssertEqual(store.openSessionCount, 2)
    }

    func testClosedRemovesAgent() {
        let store = AgentStore(notifications: NotificationSpy())
        store.apply(event("a", "running"))
        XCTAssertEqual(store.agents.count, 1)
        store.apply(event("a", "closed"))
        XCTAssertTrue(store.agents.isEmpty)
    }

    func testRemoveDismissesAgent() {
        let store = AgentStore(notifications: NotificationSpy())
        store.apply(event("a", "waiting"))
        store.remove(id: "a")
        XCTAssertTrue(store.agents.isEmpty)
    }

    func testDisabledNotificationsSuppressAll() {
        let spy = NotificationSpy()
        let store = AgentStore(
            notifications: spy,
            preferences: { NotificationPreferences(notificationsEnabled: false) }
        )
        store.apply(event("a", "waiting"))
        store.apply(event("a", "error"))
        XCTAssertTrue(spy.scheduled.isEmpty)
    }

    func testPerStatusToggleSuppressesOnlyThatStatus() {
        let spy = NotificationSpy()
        let store = AgentStore(
            notifications: spy,
            preferences: { NotificationPreferences(notifyOnWaiting: false) }
        )
        store.apply(event("a", "waiting"))
        XCTAssertTrue(spy.scheduled.isEmpty)
        store.apply(event("a", "error"))
        XCTAssertEqual(spy.scheduled.count, 1)
    }

    func testSoundPreferencePropagates() {
        let spy = NotificationSpy()
        let store = AgentStore(
            notifications: spy,
            preferences: { NotificationPreferences(soundEnabled: false) }
        )
        store.apply(event("a", "waiting"))
        XCTAssertEqual(spy.scheduled.first?.sound, false)
    }

    func testNotifiesOnAttentionTransitionsOnly() {
        let spy = NotificationSpy()
        let store = AgentStore(notifications: spy)
        store.apply(event("a", "running"))
        XCTAssertEqual(spy.scheduled.count, 0)
        store.apply(event("a", "waiting"))
        XCTAssertEqual(spy.scheduled.count, 1)
        store.apply(event("a", "waiting"))
        XCTAssertEqual(spy.scheduled.count, 1)
        store.apply(event("a", "error", title: "proj"))
        XCTAssertEqual(spy.scheduled.count, 2)
    }

    func testTitleFallsBackToCwdBasename() {
        let store = AgentStore(notifications: NotificationSpy())
        store.apply(AgentEvent(id: "a", source: "custom", title: "", cwd: "/Users/x/my-project", status: "running"))
        XCTAssertEqual(store.agents.first?.title, "my-project")
    }

    func testPruneDropsFinishedPastGrace() {
        let clock = Clock(Date(timeIntervalSince1970: 0))
        let store = AgentStore(notifications: NotificationSpy(), now: clock.provider, doneGrace: 90, staleTTL: 1800)
        store.apply(event("a", "done"))
        clock.advance(120)
        store.prune(now: clock.current)
        XCTAssertTrue(store.agents.isEmpty)
    }

    func testOllamaSyncAddsAndRemoves() {
        let store = AgentStore(notifications: NotificationSpy())
        store.syncOllama(models: ["llama3", "qwen"])
        XCTAssertEqual(store.runningCount, 2)
        store.syncOllama(models: ["llama3"])
        XCTAssertEqual(store.agents.count, 1)
        XCTAssertEqual(store.agents.first?.title, "llama3")
    }
}
