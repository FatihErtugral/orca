import XCTest
@testable import OrcaBridgeCore

final class OrcaVersionTests: XCTestCase {
    func testNewerDetection() {
        XCTAssertTrue(OrcaVersion.isNewer("v0.2.0", than: "0.1.1"))
        XCTAssertTrue(OrcaVersion.isNewer("1.0.0", than: "0.9.9"))
        XCTAssertTrue(OrcaVersion.isNewer("0.1.10", than: "0.1.9"))
    }

    func testEqualAndOlderAreNotNewer() {
        XCTAssertFalse(OrcaVersion.isNewer("v0.1.1", than: "0.1.1"))
        XCTAssertFalse(OrcaVersion.isNewer("0.1.0", than: "0.1.1"))
        XCTAssertFalse(OrcaVersion.isNewer("v0.2", than: "0.2.0"))
    }

    func testMissingComponentsTreatedAsZero() {
        XCTAssertTrue(OrcaVersion.isNewer("0.2", than: "0.1.9"))
        XCTAssertFalse(OrcaVersion.isNewer("1", than: "1.0.0"))
    }
}
