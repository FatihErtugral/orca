import XCTest
@testable import OrcaBridgeCore

final class EventBuilderTests: XCTestCase {
    private func builder(
        identity: TerminalIdentity = TerminalIdentity(),
        title: String? = nil,
        cwd: String = "/cwd"
    ) -> EventBuilder {
        EventBuilder(
            identity: StubTerminalIdentity(value: identity),
            sessionTitleProvider: { _ in title },
            now: { 123 },
            currentDirectory: { cwd }
        )
    }

    func testClaudeUsesTranscriptTitleAndTerminalIdentity() {
        let identity = TerminalIdentity(tty: "/dev/ttys1", termProgram: "iTerm.app", appBundleId: "com.x")
        let event = builder(identity: identity, title: "My Session")
            .event(flags: ["source": "claude-code", "status": "waiting", "cwd": "/a/b", "transcript": "/x"], hook: nil)

        XCTAssertEqual(event.title, "My Session")
        XCTAssertEqual(event.status, "waiting")
        XCTAssertEqual(event.tty, "/dev/ttys1")
        XCTAssertEqual(event.termProgram, "iTerm.app")
        XCTAssertEqual(event.appBundleId, "com.x")
        XCTAssertEqual(event.ts, 123)
    }

    func testHookProvidesIdCwdAndBasenameTitle() {
        let event = builder(title: nil)
            .event(flags: ["source": "claude-code"], hook: ["session_id": "abc", "cwd": "/proj", "transcript_path": "/t"])

        XCTAssertEqual(event.id, "abc")
        XCTAssertEqual(event.cwd, "/proj")
        XCTAssertEqual(event.title, "proj")
    }

    func testNonClaudeSourceIgnoresTranscriptTitle() {
        let event = builder(title: "should-not-use", cwd: "/work/dir")
            .event(flags: ["source": "custom", "id": "x"], hook: nil)

        XCTAssertEqual(event.id, "x")
        XCTAssertEqual(event.title, "dir")
    }

    func testExplicitTitleAndStatusDefaults() {
        let event = builder().event(flags: ["title": "Explicit", "id": "z"], hook: nil)
        XCTAssertEqual(event.title, "Explicit")
        XCTAssertEqual(event.source, "custom")
        XCTAssertEqual(event.status, "running")
    }

    func testStopWithPendingBackgroundStaysRunning() {
        let event = builder().event(
            flags: ["source": "claude-code", "status": "waiting"],
            hook: ["session_id": "s", "cwd": "/p", "hook_event_name": "Stop", "background_tasks_pending": true]
        )
        XCTAssertEqual(event.status, "running")
        XCTAssertEqual(event.message, "Working in background")
    }

    func testStopAwaitingBackgroundStaysRunning() {
        let event = builder().event(
            flags: ["source": "claude-code", "status": "waiting"],
            hook: ["session_id": "s", "awaiting_background": true]
        )
        XCTAssertEqual(event.status, "running")
    }

    func testStopWithoutBackgroundBecomesWaiting() {
        let event = builder().event(
            flags: ["source": "claude-code", "status": "waiting", "message": "Your turn"],
            hook: ["session_id": "s", "background_tasks_pending": false, "awaiting_background": false]
        )
        XCTAssertEqual(event.status, "waiting")
        XCTAssertEqual(event.message, "Your turn")
    }

    func testEventCarriesTranscriptPath() {
        let event = builder(title: "T").event(
            flags: ["source": "claude-code", "status": "running"],
            hook: ["session_id": "s", "transcript_path": "/t/x.jsonl"]
        )
        XCTAssertEqual(event.transcriptPath, "/t/x.jsonl")
    }
}
