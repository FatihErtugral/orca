import CryptoKit
import Foundation

/// Persists the last event of each open agent to disk so the app can rediscover
/// sessions that were already running when it launched. Only open states
/// (`running`, `waiting`) are kept; anything else removes the file.
public struct AgentStateStore {
    public let directory: URL

    public init(directory: URL = AgentStateStore.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Orca/agents", isDirectory: true)
    }

    /// Records the event if the agent is open, otherwise clears any stored file.
    public func record(_ event: AgentEvent) {
        switch event.status {
        case "running", "waiting":
            save(event)
        default:
            remove(id: event.id)
        }
    }

    public func save(_ event: AgentEvent) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(event) else { return }
        try? data.write(to: fileURL(for: event.id))
    }

    public func remove(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: String) -> URL {
        let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash + ".json")
    }
}
