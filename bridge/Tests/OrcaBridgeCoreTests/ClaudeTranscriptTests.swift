import XCTest
@testable import OrcaBridgeCore

final class ClaudeTranscriptTests: XCTestCase {
    func testUsesFirstUserMessage() {
        let content = jsonLines([
            ["type": "user", "message": ["role": "user", "content": "build a dolphin app"]]
        ])
        XCTAssertEqual(ClaudeTranscript.sessionTitle(fromContents: content), "build a dolphin app")
    }

    func testRenameWinsOverEverything() {
        let content = jsonLines([
            ["type": "user", "message": ["content": "first message"]],
            ["type": "summary", "summary": "A summary"],
            ["type": "ai-title", "aiTitle": "AI Title"],
            ["type": "agent-name", "agentName": "my-session"]
        ])
        XCTAssertEqual(ClaudeTranscript.sessionTitle(fromContents: content), "my-session")
    }

    func testAiTitleWinsOverSummaryAndUser() {
        let content = jsonLines([
            ["type": "user", "message": ["content": "first"]],
            ["type": "summary", "summary": "Sum"],
            ["type": "ai-title", "aiTitle": "Title"]
        ])
        XCTAssertEqual(ClaudeTranscript.sessionTitle(fromContents: content), "Title")
    }

    func testSkipsSystemReminderFirstMessage() {
        let content = jsonLines([
            ["type": "user", "message": ["content": "<system-reminder>ignore</system-reminder>"]],
            ["type": "user", "message": ["content": "the real request"]]
        ])
        XCTAssertEqual(ClaudeTranscript.sessionTitle(fromContents: content), "the real request")
    }

    func testJoinsArrayTextContent() {
        let content = jsonLines([
            ["type": "user", "message": ["content": [
                ["type": "text", "text": "hello"],
                ["type": "text", "text": "world"]
            ]]]
        ])
        XCTAssertEqual(ClaudeTranscript.sessionTitle(fromContents: content), "hello world")
    }

    func testTruncatesLongTitles() {
        let long = String(repeating: "a", count: 80)
        let title = ClaudeTranscript.sessionTitle(fromContents: jsonLines([
            ["type": "user", "message": ["content": long]]
        ]))
        XCTAssertNotNil(title)
        XCTAssertTrue(title!.hasSuffix("…"))
        XCTAssertLessThanOrEqual(title!.count, 61)
    }

    func testReturnsNilForEmpty() {
        XCTAssertNil(ClaudeTranscript.sessionTitle(fromContents: ""))
    }
}
