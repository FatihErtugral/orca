import XCTest
@testable import OrcaCore

final class AgentStateStoreTests: XCTestCase {
    private func makeDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("orca-load-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ event: AgentEvent, to dir: URL, name: String) throws {
        let data = try JSONEncoder().encode(event)
        try data.write(to: dir.appendingPathComponent("\(name).json"))
    }

    func testLoadsSavedEvents() throws {
        let dir = try makeDir()
        try write(AgentEvent(id: "a", source: "claude-code", title: "t", status: "waiting",
                             ts: Date().timeIntervalSince1970), to: dir, name: "one")
        let loaded = AgentStateStore(directory: dir).loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "a")
    }

    func testDropsStaleEvents() throws {
        let dir = try makeDir()
        try write(AgentEvent(id: "old", source: "custom", status: "waiting", ts: 0), to: dir, name: "old")
        let store = AgentStateStore(directory: dir)
        let loaded = store.loadAll(maxAge: 1800, now: Date(timeIntervalSince1970: 100_000))
        XCTAssertTrue(loaded.isEmpty)
    }

    func testMissingDirectoryLoadsEmpty() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("orca-missing-\(UUID().uuidString)")
        XCTAssertTrue(AgentStateStore(directory: dir).loadAll().isEmpty)
    }
}
