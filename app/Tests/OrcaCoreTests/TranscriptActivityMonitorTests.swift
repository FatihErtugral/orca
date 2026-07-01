import XCTest
@testable import OrcaCore

final class TranscriptActivityMonitorTests: XCTestCase {
    private var path = ""

    override func setUp() {
        super.setUp()
        path = NSTemporaryDirectory() + "orca-activity-\(UUID().uuidString).jsonl"
        FileManager.default.createFile(atPath: path, contents: Data())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: path)
        super.tearDown()
    }

    private func append(_ line: String) {
        let handle = FileHandle(forWritingAtPath: path)!
        handle.seekToEndOfFile()
        handle.write(Data((line + "\n").utf8))
        try? handle.close()
    }

    func testAssistantRecordCountsAsActivity() {
        let monitor = TranscriptActivityMonitor()
        monitor.rebaseline(path)
        append(#"{"type":"assistant","message":{"role":"assistant"}}"#)
        XCTAssertNotNil(monitor.lastMeaningfulActivity(path))
    }

    func testRenameRecordDoesNotCountAsActivity() {
        let monitor = TranscriptActivityMonitor()
        monitor.rebaseline(path)
        append(#"{"type":"agent-name","agentName":"new-name","sessionId":"s"}"#)
        append(#"{"type":"ai-title","aiTitle":"t"}"#)
        append(#"{"type":"summary","summary":"s"}"#)
        XCTAssertNil(monitor.lastMeaningfulActivity(path))
    }

    func testActivityBeforeRebaselineIsIgnored() {
        let monitor = TranscriptActivityMonitor()
        append(#"{"type":"assistant","message":{}}"#)
        monitor.rebaseline(path)
        XCTAssertNil(monitor.lastMeaningfulActivity(path))
    }

    func testRebaselineClearsPreviousActivity() {
        let monitor = TranscriptActivityMonitor()
        monitor.rebaseline(path)
        append(#"{"type":"assistant","message":{}}"#)
        XCTAssertNotNil(monitor.lastMeaningfulActivity(path))
        monitor.rebaseline(path)
        XCTAssertNil(monitor.lastMeaningfulActivity(path))
    }

    func testPartialLineIsNotConsumedUntilComplete() {
        let monitor = TranscriptActivityMonitor()
        monitor.rebaseline(path)

        let handle = FileHandle(forWritingAtPath: path)!
        handle.seekToEndOfFile()
        handle.write(Data(#"{"type":"assis"#.utf8))
        try? handle.close()
        XCTAssertNil(monitor.lastMeaningfulActivity(path))

        let handle2 = FileHandle(forWritingAtPath: path)!
        handle2.seekToEndOfFile()
        handle2.write(Data(("tant\",\"x\":1}" + "\n").utf8))
        try? handle2.close()
        XCTAssertNotNil(monitor.lastMeaningfulActivity(path))
    }
}
