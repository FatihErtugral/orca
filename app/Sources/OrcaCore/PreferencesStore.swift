import Combine
import Foundation

public struct NotificationPreferences: Equatable {
    public var notificationsEnabled: Bool
    public var notifyOnWaiting: Bool
    public var notifyOnDone: Bool
    public var notifyOnError: Bool
    public var soundEnabled: Bool

    public init(
        notificationsEnabled: Bool = true,
        notifyOnWaiting: Bool = true,
        notifyOnDone: Bool = true,
        notifyOnError: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.notifyOnWaiting = notifyOnWaiting
        self.notifyOnDone = notifyOnDone
        self.notifyOnError = notifyOnError
        self.soundEnabled = soundEnabled
    }

    /// Whether a transition into `status` should produce a notification.
    public func shouldNotify(for status: AgentStatus) -> Bool {
        guard notificationsEnabled else { return false }
        switch status {
        case .waiting: return notifyOnWaiting
        case .done: return notifyOnDone
        case .error: return notifyOnError
        case .running, .idle: return false
        }
    }
}

/// Observable, UserDefaults-backed preferences. The defaults suite is injectable
/// so tests can use an isolated store.
public final class PreferencesStore: ObservableObject {
    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let notifyOnWaiting = "notifyOnWaiting"
        static let notifyOnDone = "notifyOnDone"
        static let notifyOnError = "notifyOnError"
        static let soundEnabled = "soundEnabled"
    }

    @Published public var preferences: NotificationPreferences {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = NotificationPreferences(
            notificationsEnabled: Self.bool(defaults, Key.notificationsEnabled, fallback: true),
            notifyOnWaiting: Self.bool(defaults, Key.notifyOnWaiting, fallback: true),
            notifyOnDone: Self.bool(defaults, Key.notifyOnDone, fallback: true),
            notifyOnError: Self.bool(defaults, Key.notifyOnError, fallback: true),
            soundEnabled: Self.bool(defaults, Key.soundEnabled, fallback: true)
        )
    }

    private func persist() {
        defaults.set(preferences.notificationsEnabled, forKey: Key.notificationsEnabled)
        defaults.set(preferences.notifyOnWaiting, forKey: Key.notifyOnWaiting)
        defaults.set(preferences.notifyOnDone, forKey: Key.notifyOnDone)
        defaults.set(preferences.notifyOnError, forKey: Key.notifyOnError)
        defaults.set(preferences.soundEnabled, forKey: Key.soundEnabled)
    }

    private static func bool(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}
