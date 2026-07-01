import CryptoKit
import Foundation

/// Reads the open-session state the bridge persists, so the app can show
/// sessions that were already running before it launched.
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

    /// Loads persisted events, dropping (and deleting) anything older than `maxAge`.
    public func loadAll(maxAge: TimeInterval = 1800, now: Date = Date()) -> [AgentEvent] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []

        var events: [AgentEvent] = []
        for file in files where file.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: file),
                let event = try? JSONDecoder().decode(AgentEvent.self, from: data)
            else { continue }

            if let ts = event.ts, now.timeIntervalSince1970 - ts > maxAge {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            events.append(event)
        }
        return events
    }

    public func remove(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: String) -> URL {
        let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash + ".json")
    }
}
