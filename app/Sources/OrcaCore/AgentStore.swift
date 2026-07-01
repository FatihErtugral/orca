import Combine
import Foundation

/// Observable, in-memory model of every agent Orca knows about. All mutation
/// happens on the main thread; callers hop to main before applying events.
public final class AgentStore: ObservableObject {
    @Published public private(set) var agents: [Agent] = []

    private var map: [String: Agent] = [:]
    private var ollamaIDs: Set<String> = []

    private let notifications: NotificationScheduling
    private let preferences: () -> NotificationPreferences
    private let now: () -> Date
    private let doneGrace: TimeInterval
    private let staleTTL: TimeInterval
    private let activity: TranscriptActivityTracking
    private let processAlive: (Int32) -> Bool
    private let waitingConfirmDelay: TimeInterval
    private let quietRevertDelay: TimeInterval
    private var pruneTimer: Timer?

    /// Waiting notifications held back until the transcript stays quiet, so a
    /// session that auto-resumes (background tasks, worktree agents) never
    /// produces a false "your turn".
    private var pendingWaiting: [String: Date] = [:]

    public init(
        notifications: NotificationScheduling,
        preferences: @escaping () -> NotificationPreferences = { NotificationPreferences() },
        now: @escaping () -> Date = Date.init,
        doneGrace: TimeInterval = 90,
        staleTTL: TimeInterval = 1800,
        activity: TranscriptActivityTracking = TranscriptActivityMonitor(),
        processAlive: @escaping (Int32) -> Bool = AgentStore.isProcessAlive,
        waitingConfirmDelay: TimeInterval = 6,
        quietRevertDelay: TimeInterval = 30
    ) {
        self.notifications = notifications
        self.preferences = preferences
        self.now = now
        self.doneGrace = doneGrace
        self.staleTTL = staleTTL
        self.activity = activity
        self.processAlive = processAlive
        self.waitingConfirmDelay = waitingConfirmDelay
        self.quietRevertDelay = quietRevertDelay
    }

    public static func isProcessAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// Count of agents actively working (drives the left number in the badge).
    public var runningCount: Int {
        agents.reduce(0) { $0 + ($1.status == .running ? 1 : 0) }
    }

    /// Count of open sessions — everything except finished/idle (right number).
    public var openSessionCount: Int {
        agents.reduce(0) { $0 + (($1.status == .done || $1.status == .idle) ? 0 : 1) }
    }

    public func startMaintenance(interval: TimeInterval = 3) {
        pruneTimer?.invalidate()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.evaluateHealth()
            self.prune(now: self.now())
        }
    }

    /// Reconciles reported hook state with transcript ground truth, in BOTH
    /// directions so the state always converges: activity promotes a "waiting"
    /// session to running (auto-resume the hooks can't see), sustained quiet
    /// demotes an activity-promoted session back to waiting (a late flush after
    /// the stop must not latch it as running forever). Also removes agents whose
    /// owning process died and releases debounced waiting notifications.
    public func evaluateHealth() {
        let currentTime = now()
        var changed = false

        for agent in map.values {
            if let pid = agent.pid, !processAlive(pid) {
                map.removeValue(forKey: agent.id)
                pendingWaiting.removeValue(forKey: agent.id)
                changed = true
                continue
            }

            guard let path = agent.transcriptPath else { continue }
            let lastActivity = activity.lastMeaningfulActivity(path)

            if agent.status == .waiting, let modified = lastActivity {
                var revived = agent
                revived.status = .running
                revived.message = "Working…"
                revived.revivedByActivity = true
                revived.runStartedAt = revived.runStartedAt ?? modified
                revived.lastUpdate = currentTime
                map[agent.id] = revived
                pendingWaiting.removeValue(forKey: agent.id)
                changed = true
            } else if agent.status == .running, agent.revivedByActivity,
                      let modified = lastActivity,
                      currentTime.timeIntervalSince(modified) >= quietRevertDelay {
                var demoted = agent
                demoted.status = .waiting
                demoted.message = "Waiting for you"
                demoted.revivedByActivity = false
                if let start = demoted.runStartedAt {
                    demoted.lastRunDuration = modified.timeIntervalSince(start)
                }
                demoted.runStartedAt = nil
                demoted.lastUpdate = currentTime
                map[agent.id] = demoted
                activity.rebaseline(path)
                pendingWaiting[agent.id] = currentTime
                changed = true
            }
        }

        for (id, since) in pendingWaiting {
            guard let agent = map[id], agent.status == .waiting else {
                pendingWaiting.removeValue(forKey: id)
                continue
            }
            guard currentTime.timeIntervalSince(since) >= waitingConfirmDelay else { continue }
            // The transcript was rebaselined when the stop arrived, so any
            // meaningful record since then means Claude resumed — never notify.
            let resumed = agent.transcriptPath.flatMap { activity.lastMeaningfulActivity($0) } != nil
            if !resumed {
                pendingWaiting.removeValue(forKey: id)
                notify(agent)
            }
        }

        if changed { publish() }
    }

    public func apply(_ event: AgentEvent) {
        if event.status == "closed" || event.status == "ended" {
            map.removeValue(forKey: event.id)
            pendingWaiting.removeValue(forKey: event.id)
            publish()
            return
        }

        let status = AgentStatus(rawValue: event.status) ?? .running
        let previous = map[event.id]?.status
        let timestamp = now()

        var agent = map[event.id] ?? Agent(
            id: event.id,
            source: event.source,
            title: "",
            cwd: event.cwd,
            status: status,
            message: event.message,
            lastUpdate: timestamp
        )

        updateRunTiming(&agent, previous: previous, next: status, at: timestamp)

        agent.source = event.source
        if let cwd = event.cwd { agent.cwd = cwd }
        if let title = event.title, !title.isEmpty {
            agent.title = title
        } else if agent.title.isEmpty {
            agent.title = Self.displayTitle(for: event)
        }
        if let tty = event.tty { agent.tty = tty }
        if let termProgram = event.termProgram { agent.termProgram = termProgram }
        if let session = event.session { agent.session = session }
        if let appBundleId = event.appBundleId { agent.appBundleId = appBundleId }
        if let transcriptPath = event.transcriptPath { agent.transcriptPath = transcriptPath }
        if let pid = event.pid { agent.pid = pid }
        agent.status = status
        agent.message = event.message
        agent.lastUpdate = timestamp
        agent.revivedByActivity = false

        map[event.id] = agent

        if status != .waiting { pendingWaiting.removeValue(forKey: event.id) }
        publish()

        guard previous != status else { return }
        // Waiting on a session with a transcript is only announced once no real
        // work records follow the stop (see evaluateHealth) — Claude may
        // auto-resume after background tasks.
        if status == .waiting, let path = agent.transcriptPath {
            activity.rebaseline(path)
            pendingWaiting[event.id] = timestamp
        } else {
            notify(agent)
        }
    }

    /// Update a title out-of-band (e.g. after a /rename is detected in the transcript).
    public func updateTitle(id: String, title: String) {
        guard var agent = map[id], agent.title != title, !title.isEmpty else { return }
        agent.title = title
        map[id] = agent
        publish()
    }

    public func syncOllama(models: [String]) {
        let current = Set(models.map { "ollama:\($0)" })
        let timestamp = now()
        for name in models {
            let id = "ollama:\(name)"
            var agent = map[id] ?? Agent(id: id, source: "ollama", title: name, status: .running, lastUpdate: timestamp)
            if agent.runStartedAt == nil { agent.runStartedAt = timestamp }
            agent.status = .running
            agent.lastUpdate = timestamp
            map[id] = agent
        }
        for stale in ollamaIDs.subtracting(current) {
            map.removeValue(forKey: stale)
        }
        ollamaIDs = current
        publish()
    }

    /// Manually dismiss a single agent (e.g. a waiting session you're done with).
    public func remove(id: String) {
        map.removeValue(forKey: id)
        pendingWaiting.removeValue(forKey: id)
        publish()
    }

    func prune(now: Date) {
        map = map.filter { _, agent in
            let age = now.timeIntervalSince(agent.lastUpdate)
            if agent.status == .done || agent.status == .idle { return age < doneGrace }
            // Agents with a pid are governed by process liveness (evaluateHealth),
            // not by an arbitrary age cutoff — an idle-but-open session stays.
            if agent.pid != nil { return true }
            return age < staleTTL
        }
        publish()
    }

    private func updateRunTiming(_ agent: inout Agent, previous: AgentStatus?, next: AgentStatus, at time: Date) {
        let wasRunning = previous == .running
        let willRun = next == .running
        if willRun, !wasRunning {
            agent.runStartedAt = time
        } else if !willRun, wasRunning {
            if let start = agent.runStartedAt {
                agent.lastRunDuration = time.timeIntervalSince(start)
            }
            agent.runStartedAt = nil
        }
    }

    private func publish() {
        agents = map.values.sorted {
            if $0.status.priority != $1.status.priority {
                return $0.status.priority < $1.status.priority
            }
            return $0.lastUpdate > $1.lastUpdate
        }
    }

    private func notify(_ agent: Agent) {
        let prefs = preferences()
        guard prefs.shouldNotify(for: agent.status) else { return }

        let sound = prefs.soundEnabled
        switch agent.status {
        case .waiting:
            notifications.schedule(title: "⏳ \(agent.title)", body: agent.message ?? "Waiting for you", sound: sound)
        case .done:
            notifications.schedule(title: "✅ \(agent.title)", body: agent.message ?? "Finished", sound: sound)
        case .error:
            notifications.schedule(title: "❌ \(agent.title)", body: agent.message ?? "Error", sound: sound)
        case .running, .idle:
            break
        }
    }

    private static func displayTitle(for event: AgentEvent) -> String {
        if let cwd = event.cwd, !cwd.isEmpty {
            return (cwd as NSString).lastPathComponent
        }
        return event.id
    }
}
