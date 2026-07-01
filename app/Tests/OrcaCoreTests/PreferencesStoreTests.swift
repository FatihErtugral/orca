import XCTest
@testable import OrcaCore

final class PreferencesStoreTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let suite = "orca-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testDefaultsAreAllEnabled() {
        let store = PreferencesStore(defaults: isolatedDefaults())
        XCTAssertTrue(store.preferences.notificationsEnabled)
        XCTAssertTrue(store.preferences.notifyOnWaiting)
        XCTAssertTrue(store.preferences.soundEnabled)
    }

    func testChangesPersistAcrossInstances() {
        let defaults = isolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.preferences.soundEnabled = false
        store.preferences.notifyOnDone = false

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertFalse(reloaded.preferences.soundEnabled)
        XCTAssertFalse(reloaded.preferences.notifyOnDone)
        XCTAssertTrue(reloaded.preferences.notifyOnWaiting)
    }

    func testShouldNotifyRespectsMasterAndPerStatus() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(prefs.shouldNotify(for: .waiting))
        XCTAssertFalse(prefs.shouldNotify(for: .running))

        prefs.notifyOnWaiting = false
        XCTAssertFalse(prefs.shouldNotify(for: .waiting))
        XCTAssertTrue(prefs.shouldNotify(for: .error))

        prefs.notificationsEnabled = false
        XCTAssertFalse(prefs.shouldNotify(for: .error))
    }
}
