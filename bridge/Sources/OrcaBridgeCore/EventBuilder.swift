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

        return decorate(
            AgentEvent(
                id: id,
                source: source,
                title: title,
                cwd: cwd,
                status: flags["status"] ?? "running",
                message: flags["message"]
            )
        )
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
        return event
    }

    static func basename(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
