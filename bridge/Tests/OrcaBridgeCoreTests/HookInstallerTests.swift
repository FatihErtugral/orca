import XCTest
@testable import OrcaBridgeCore

final class HookInstallerTests: XCTestCase {
    private let exe = "/usr/local/bin/orca"

    private func agentBarEntries(_ root: [String: Any], event: String) -> [[String: Any]] {
        let hooks = root["hooks"] as? [String: Any] ?? [:]
        let entries = hooks[event] as? [[String: Any]] ?? []
        return entries.filter { entry in
            let inner = entry["hooks"] as? [[String: Any]] ?? []
            return inner.contains { ($0["command"] as? String)?.contains("orca event") == true }
        }
    }

    func testInstallAddsAllHooksAndPreservesSettings() {
        let path = makeTempSettings(["theme": "dark"])
        let installer = HookInstaller(settingsPath: path, executablePath: exe)
        XCTAssertTrue(installer.install())

        let root = readJSON(path)
        XCTAssertEqual(root["theme"] as? String, "dark")
        for (event, _) in installer.hooks() {
            XCTAssertEqual(agentBarEntries(root, event: event).count, 1, "missing hook \(event)")
        }
    }

    func testInstallPreservesUsersOwnHookOnSameEvent() {
        let path = makeTempSettings([
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo mine"]]]]]
        ])
        let installer = HookInstaller(settingsPath: path, executablePath: exe)
        XCTAssertTrue(installer.install())

        let stop = (readJSON(path)["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop.count, 2)
    }

    func testInstallIsIdempotent() {
        let path = makeTempSettings(nil)
        let installer = HookInstaller(settingsPath: path, executablePath: exe)
        XCTAssertTrue(installer.install())
        XCTAssertTrue(installer.install())
        XCTAssertEqual(agentBarEntries(readJSON(path), event: "Stop").count, 1)
    }

    func testUninstallRemovesOnlyOrcaHooks() {
        let path = makeTempSettings([
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo mine"]]]]]
        ])
        let installer = HookInstaller(settingsPath: path, executablePath: exe)
        XCTAssertTrue(installer.install())
        XCTAssertTrue(installer.uninstall())

        let root = readJSON(path)
        XCTAssertEqual(agentBarEntries(root, event: "Stop").count, 0)
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop.count, 1)
    }
}
