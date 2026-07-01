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
}
