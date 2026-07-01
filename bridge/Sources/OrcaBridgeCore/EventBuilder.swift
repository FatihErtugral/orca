import Foundation

/// Builds `AgentEvent`s from parsed flags and optional hook payloads. Collaborators
/// are injected so the resolution logic can be tested without a real terminal,
/// clock, or transcript file.
public struct EventBuilder {
    private let identity: TerminalIdentityResolving
    private let sessionTitleProvider: (String) -> String?
    private let now: () -> Double
    private let currentDirectory: () -> String

    public init(
        identity: TerminalIdentityResolving = SystemTerminalIdentity(),
        sessionTitleProvider: @escaping (String) -> String? = ClaudeTranscript.sessionTitle(transcriptPath:),
        now: @escaping () -> Double = { Date().timeIntervalSince1970 },
        currentDirectory: @escaping () -> String = { FileManager.default.currentDirectoryPath }
    ) {
        self.identity = identity
        self.sessionTitleProvider = sessionTitleProvider
        self.now = now
        self.currentDirectory = currentDirectory
    }

    public func event(flags: [String: String], hook: [String: Any]?) -> AgentEvent {
        let source = flags["source"] ?? "custom"
        let cwd = flags["cwd"] ?? (hook?["cwd"] as? String) ?? currentDirectory()
        let id = flags["id"] ?? (hook?["session_id"] as? String) ?? cwd
        let transcriptPath = flags["transcript"] ?? (hook?["transcript_path"] as? String)
        let sessionTitle = source == "claude-code" ? transcriptPath.flatMap(sessionTitleProvider) : nil
        let title = flags["title"] ?? sessionTitle ?? Self.basename(cwd)

        var status = flags["status"] ?? "running"
        var message = flags["message"]
        // A Stop that fires while background tasks are still pending is not
        // "your turn" — Claude will auto-resume, so keep the agent running.
        if status == "waiting", Self.backgroundWorkPending(hook) {
            status = "running"
            message = "Working in background"
        }

        return decorate(
            AgentEvent(
                id: id,
                source: source,
                title: title,
                cwd: cwd,
                status: status,
                message: message,
                transcriptPath: transcriptPath,
                permissionMode: hook?["permission_mode"] as? String
            )
        )
    }

    static func backgroundWorkPending(_ hook: [String: Any]?) -> Bool {
        guard let hook = hook else { return false }
        let pending = hook["background_tasks_pending"] as? Bool ?? false
        let awaiting = hook["awaiting_background"] as? Bool ?? false
        return pending || awaiting
    }

    public func wrapEvent(
        id: String,
        source: String,
        title: String,
        cwd: String,
        status: String,
        message: String?
    ) -> AgentEvent {
        decorate(AgentEvent(id: id, source: source, title: title, cwd: cwd, status: status, message: message))
    }

    private func decorate(_ base: AgentEvent) -> AgentEvent {
        var event = base
        let terminal = identity.resolve()
        event.ts = now()
        event.tty = terminal.tty
        event.termProgram = terminal.termProgram
        event.session = terminal.session
        event.appBundleId = terminal.appBundleId
        event.pid = SystemTerminalIdentity.originatorPID()
        return event
    }

    static func basename(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
