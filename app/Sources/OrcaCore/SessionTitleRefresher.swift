import Foundation

/// Keeps Claude session titles fresh between hook events (e.g. after /rename),
/// by re-deriving them from each open session's transcript. Transcripts are only
/// re-parsed when their modification date changes.
public final class SessionTitleRefresher {
    private let titleProvider: (String) -> String?
    private let modificationDate: (String) -> Date?
    private var lastSeen: [String: Date] = [:]
    private var timer: Timer?

    public init(
        titleProvider: @escaping (String) -> String? = ClaudeTranscript.sessionTitle(transcriptPath:),
        modificationDate: @escaping (String) -> Date? = SessionTitleRefresher.fileModificationDate
    ) {
        self.titleProvider = titleProvider
        self.modificationDate = modificationDate
    }

    public func start(interval: TimeInterval = 3, store: AgentStore) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak store] _ in
            guard let self = self, let store = store else { return }
            self.refresh(store: store)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func refresh(store: AgentStore) {
        for agent in store.agents where agent.source == "claude-code" && agent.isActive {
            guard let path = agent.transcriptPath else { continue }
            guard let modified = modificationDate(path) else { continue }
            if let seen = lastSeen[path], seen >= modified { continue }
            lastSeen[path] = modified

            if let title = titleProvider(path) {
                store.updateTitle(id: agent.id, title: title)
            }
        }
    }

    public static func fileModificationDate(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
}
