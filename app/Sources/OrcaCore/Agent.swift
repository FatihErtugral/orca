import Foundation

public enum AgentStatus: String {
    case running, waiting, done, error, idle

    /// Menu sort priority — things needing attention float to the top.
    public var priority: Int {
        switch self {
        case .waiting: return 0
        case .error: return 1
        case .running: return 2
        case .done: return 3
        case .idle: return 4
        }
    }
}

public struct Agent: Identifiable, Equatable {
    public let id: String
    public var source: String
    public var title: String
    public var cwd: String?
    public var status: AgentStatus
    public var message: String?
    public var lastUpdate: Date

    /// Start of the current running period (nil when not running).
    public var runStartedAt: Date?
    /// Duration of the most recently completed running period.
    public var lastRunDuration: TimeInterval

    public var tty: String?
    public var termProgram: String?
    public var session: String?
    public var appBundleId: String?
    public var transcriptPath: String?

    public init(
        id: String,
        source: String,
        title: String,
        cwd: String? = nil,
        status: AgentStatus,
        message: String? = nil,
        lastUpdate: Date,
        runStartedAt: Date? = nil,
        lastRunDuration: TimeInterval = 0,
        tty: String? = nil,
        termProgram: String? = nil,
        session: String? = nil,
        appBundleId: String? = nil,
        transcriptPath: String? = nil
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.cwd = cwd
        self.status = status
        self.message = message
        self.lastUpdate = lastUpdate
        self.runStartedAt = runStartedAt
        self.lastRunDuration = lastRunDuration
        self.tty = tty
        self.termProgram = termProgram
        self.session = session
        self.appBundleId = appBundleId
        self.transcriptPath = transcriptPath
    }

    /// Whether the agent is running or waiting (i.e. an open, live session).
    public var isActive: Bool { status == .running || status == .waiting }

    /// Ticks only while running; otherwise the last completed run's duration.
    public func duration(now: Date) -> TimeInterval {
        if status == .running, let start = runStartedAt {
            return max(0, now.timeIntervalSince(start))
        }
        return lastRunDuration
    }
}
