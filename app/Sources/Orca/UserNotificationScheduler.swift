import OrcaCore
import Foundation
import UserNotifications

/// Concrete `NotificationScheduling` backed by UNUserNotificationCenter. Requires
/// the process to run from a proper .app bundle.
final class UserNotificationScheduler: NotificationScheduling {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
