import XCTest
@testable import OrcaCore

final class TerminalActivatingTests: XCTestCase {
    private func agent(termProgram: String?, tty: String? = nil) -> Agent {
        Agent(id: "a", source: "claude-code", title: "t", cwd: "/p", status: .running,
              lastUpdate: Date(), tty: tty, termProgram: termProgram)
    }

    func testActivatorsMatchTheirTerminal() {
        XCTAssertTrue(AppleTerminalActivator().canActivate(agent(termProgram: "Apple_Terminal")))
        XCTAssertFalse(AppleTerminalActivator().canActivate(agent(termProgram: "iTerm.app")))
        XCTAssertTrue(ITermActivator().canActivate(agent(termProgram: "iTerm.app")))
        XCTAssertTrue(VSCodeFamilyActivator().canActivate(agent(termProgram: "vscode")))
        XCTAssertTrue(GenericAppActivator().canActivate(agent(termProgram: "anything")))
    }

    func testKnownVSCodeSchemes() {
        XCTAssertEqual(VSCodeFamilyActivator.urlScheme(forBundleId: "com.microsoft.VSCode"), "vscode")
        XCTAssertEqual(VSCodeFamilyActivator.urlScheme(forBundleId: "com.exafunction.windsurf"), "windsurf")
    }

    func testGenericBundleIdMapping() {
        XCTAssertEqual(GenericAppActivator.bundleId(for: "Apple_Terminal"), "com.apple.Terminal")
        XCTAssertEqual(GenericAppActivator.bundleId(for: "ghostty"), "com.mitchellh.ghostty")
        XCTAssertNil(GenericAppActivator.bundleId(for: "unknown-term"))
    }
}
