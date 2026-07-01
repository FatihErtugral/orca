import XCTest
@testable import OrcaCore

private final class NoopNotifier: NotificationScheduling {
    func schedule(title: String, body: String, sound: Bool) {}
}

final class SessionTitleRefresherTests: XCTestCase {
    private func makeStore(withAgent transcriptPath: String?) -> AgentStore {
        let store = AgentStore(notifications: NoopNotifier())
        store.apply(AgentEvent(
            id: "s1", source: "claude-code", title: "old-title", cwd: "/p",
            status: "running", transcriptPath: transcriptPath
        ))
        return store
    }

    func testUpdatesTitleWhenTranscriptChanges() {
        let store = makeStore(withAgent: "/t/x.jsonl")
        var modified = Date(timeIntervalSince1970: 100)
        let refresher = SessionTitleRefresher(
            titleProvider: { _ in "renamed-title" },
            modificationDate: { _ in modified }
        )

        refresher.refresh(store: store)
        XCTAssertEqual(store.agents.first?.title, "renamed-title")

        modified = Date(timeIntervalSince1970: 200)
        refresher.refresh(store: store)
        XCTAssertEqual(store.agents.first?.title, "renamed-title")
    }

    func testSkipsReparseWhenUnmodified() {
        let store = makeStore(withAgent: "/t/x.jsonl")
        var parses = 0
        let refresher = SessionTitleRefresher(
            titleProvider: { _ in parses += 1; return "t" },
            modificationDate: { _ in Date(timeIntervalSince1970: 100) }
        )
        refresher.refresh(store: store)
        refresher.refresh(store: store)
        XCTAssertEqual(parses, 1)
    }

    func testIgnoresNonClaudeAndClosedAgents() {
        let store = AgentStore(notifications: NoopNotifier())
        store.apply(AgentEvent(id: "x", source: "custom", title: "keep", cwd: "/p",
                               status: "running", transcriptPath: "/t/x.jsonl"))
        let refresher = SessionTitleRefresher(
            titleProvider: { _ in "should-not-apply" },
            modificationDate: { _ in Date() }
        )
        refresher.refresh(store: store)
        XCTAssertEqual(store.agents.first?.title, "keep")
    }
}
