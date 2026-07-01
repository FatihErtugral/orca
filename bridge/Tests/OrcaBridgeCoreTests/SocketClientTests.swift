import XCTest
@testable import OrcaBridgeCore

final class SocketClientTests: XCTestCase {
    func testSendDeliversNewlineDelimitedJSON() throws {
        let path = NSTemporaryDirectory() + "orca-\(UUID().uuidString).sock"
        let received = expectation(description: "received event")
        var payload: Data?

        let server = UnixSocketTestServer(path: path) { data in
            payload = data
            received.fulfill()
        }
        try server.start()
        defer { server.stop() }

        let client = SocketClient(path: path)
        let event = AgentEvent(id: "t1", source: "custom", title: "demo", status: "running")
        XCTAssertTrue(client.send(event))

        wait(for: [received], timeout: 2)
        let decoded = try JSONDecoder().decode(AgentEvent.self, from: XCTUnwrap(payload))
        XCTAssertEqual(decoded.id, "t1")
        XCTAssertEqual(decoded.source, "custom")
        XCTAssertEqual(decoded.status, "running")
    }

    func testSendReturnsFalseWhenNoServer() {
        let client = SocketClient(path: NSTemporaryDirectory() + "nonexistent-\(UUID().uuidString).sock")
        XCTAssertFalse(client.send(AgentEvent(id: "x", source: "custom", status: "running")))
    }
}
