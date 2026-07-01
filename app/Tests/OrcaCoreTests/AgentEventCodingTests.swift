import XCTest
@testable import OrcaCore

final class AgentEventCodingTests: XCTestCase {
    func testDecodesSnakeCaseKeys() throws {
        let json = """
        {"id":"s1","source":"claude-code","status":"waiting","cwd":"/p",
         "tty":"/dev/ttys003","term_program":"iTerm.app","app_bundle_id":"com.x","session":"w0"}
        """
        let event = try JSONDecoder().decode(AgentEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.termProgram, "iTerm.app")
        XCTAssertEqual(event.appBundleId, "com.x")
        XCTAssertEqual(event.tty, "/dev/ttys003")
    }

    func testRoundTripsSnakeCaseKeys() throws {
        let event = AgentEvent(id: "x", source: "custom", status: "running",
                               termProgram: "vscode", appBundleId: "com.microsoft.VSCode")
        let data = try JSONEncoder().encode(event)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(object["term_program"] as? String, "vscode")
        XCTAssertEqual(object["app_bundle_id"] as? String, "com.microsoft.VSCode")
    }
}
