import Foundation

/// Abstraction over user notifications so `AgentStore` can be tested with a spy
/// and the concrete UNUserNotificationCenter implementation lives in the app.
public protocol NotificationScheduling {
    func schedule(title: String, body: String)
}
