import Foundation

/// The wire protocol shared with the bridge. Received as a single line of JSON.
public struct AgentEvent: Codable, Equatable {
    public var id: String
    public var source: String
    public var title: String?
    public var cwd: String?
    public var status: String
    public var message: String?
    public var ts: Double?
    public var tty: String?
    public var termProgram: String?
    public var session: String?
    public var appBundleId: String?
    public var transcriptPath: String?

    public init(
        id: String,
        source: String,
        title: String? = nil,
        cwd: String? = nil,
        status: String,
        message: String? = nil,
        ts: Double? = nil,
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
        self.ts = ts
        self.tty = tty
        self.termProgram = termProgram
        self.session = session
        self.appBundleId = appBundleId
        self.transcriptPath = transcriptPath
    }

    enum CodingKeys: String, CodingKey {
        case id, source, title, cwd, status, message, ts, tty, session
        case termProgram = "term_program"
        case appBundleId = "app_bundle_id"
        case transcriptPath = "transcript_path"
    }
}
