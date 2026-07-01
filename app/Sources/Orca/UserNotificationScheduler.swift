import AppKit
import Foundation
import OrcaCore
import UserNotifications

/// Concrete `NotificationScheduling` backed by UNUserNotificationCenter. Requires
/// the process to run from a proper .app bundle.
final class UserNotificationScheduler: NotificationScheduling {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Called when the user re-enables notifications in settings. macOS never
    /// re-prompts after a denial, so in that case open System Settings straight
    /// to Orca's notification pane.
    func ensurePermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization()
            case .denied:
                DispatchQueue.main.async {
                    let pane = "x-apple.systempreferences:com.apple.preference.notifications"
                    let bundleId = Bundle.main.bundleIdentifier ?? "com.orca.app"
                    let url = URL(string: "\(pane)?id=\(bundleId)")!
                    NSWorkspace.shared.open(url)
                }
            default:
                break
            }
        }
    }

    func schedule(title: String, body: String, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
