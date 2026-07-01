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

    /// Loads persisted open-session events. Events carrying a pid are kept
    /// exactly as long as that process is alive; `maxAge` is only the fallback
    /// for events from sources that have no pid.
    public func loadAll(
        maxAge: TimeInterval = 1800,
        now: Date = Date(),
        processAlive: (Int32) -> Bool = AgentStore.isProcessAlive
    ) -> [AgentEvent] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []

        var events: [AgentEvent] = []
        for file in files where file.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: file),
                let event = try? JSONDecoder().decode(AgentEvent.self, from: data)
            else { continue }

            let stale: Bool
            if let pid = event.pid {
                stale = !processAlive(pid)
            } else {
                stale = event.ts.map { now.timeIntervalSince1970 - $0 > maxAge } ?? true
            }
            if stale {
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
