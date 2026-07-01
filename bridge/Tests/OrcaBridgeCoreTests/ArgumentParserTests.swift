import XCTest
@testable import OrcaBridgeCore

final class ArgumentParserTests: XCTestCase {
    func testParsesFlagValuePairs() {
        let parsed = ArgumentParser.parse(["--source", "custom", "--status", "running"])
        XCTAssertEqual(parsed.flags["source"], "custom")
        XCTAssertEqual(parsed.flags["status"], "running")
        XCTAssertTrue(parsed.rest.isEmpty)
    }

    func testValuelessFlagBecomesEmptyString() {
        let parsed = ArgumentParser.parse(["--verbose", "--id", "x"])
        XCTAssertEqual(parsed.flags["verbose"], "")
        XCTAssertEqual(parsed.flags["id"], "x")
    }

    func testCapturesPassthroughAfterDoubleDash() {
        let parsed = ArgumentParser.parse(["--source", "custom", "--", "sleep", "3"])
        XCTAssertEqual(parsed.flags["source"], "custom")
        XCTAssertEqual(parsed.rest, ["sleep", "3"])
    }
}
