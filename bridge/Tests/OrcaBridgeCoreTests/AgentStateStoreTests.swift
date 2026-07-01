import XCTest
@testable import OrcaBridgeCore

final class AgentStateStoreTests: XCTestCase {
    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("orca-state-\(UUID().uuidString)")
    }

    private func jsonCount(_ dir: URL) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.count
    }

    func testRecordSavesOpenStates() {
        let dir = tempDir()
        let store = AgentStateStore(directory: dir)
        store.record(AgentEvent(id: "a", source: "custom", status: "running"))
        store.record(AgentEvent(id: "b", source: "custom", status: "waiting"))
        XCTAssertEqual(jsonCount(dir), 2)
    }

    func testRecordRemovesClosedOrFinishedStates() {
        let dir = tempDir()
        let store = AgentStateStore(directory: dir)
        store.record(AgentEvent(id: "a", source: "custom", status: "running"))
        store.record(AgentEvent(id: "a", source: "custom", status: "done"))
        XCTAssertEqual(jsonCount(dir), 0)

        store.record(AgentEvent(id: "b", source: "custom", status: "waiting"))
        store.record(AgentEvent(id: "b", source: "custom", status: "closed"))
        XCTAssertEqual(jsonCount(dir), 0)
    }
}
