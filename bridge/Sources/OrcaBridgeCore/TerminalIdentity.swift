import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct TerminalIdentity: Equatable {
    public var tty: String?
    public var termProgram: String?
    public var session: String?
    public var appBundleId: String?

    public init(tty: String? = nil, termProgram: String? = nil, session: String? = nil, appBundleId: String? = nil) {
        self.tty = tty
        self.termProgram = termProgram
        self.session = session
        self.appBundleId = appBundleId
    }
}

public protocol TerminalIdentityResolving {
    func resolve() -> TerminalIdentity
}

public struct SystemTerminalIdentity: TerminalIdentityResolving {
    public init() {}

    public func resolve() -> TerminalIdentity {
        let env = ProcessInfo.processInfo.environment
        return TerminalIdentity(
            tty: Self.controllingTTY(),
            termProgram: env["TERM_PROGRAM"],
            session: env["ITERM_SESSION_ID"] ?? env["TERM_SESSION_ID"],
            appBundleId: env["__CFBundleIdentifier"]
        )
    }

    /// Resolves the controlling terminal device (e.g. `/dev/ttys003`) via
    /// `proc_pidinfo`, which survives even when stdio are pipes (the hook case)
    /// and yields the concrete device name rather than `/dev/tty`.
    static func controllingTTY() -> String? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        if proc_pidinfo(getpid(), PROC_PIDTBSDINFO, 0, &info, size) == size,
           info.e_tdev != 0, info.e_tdev != UInt32.max,
           let cname = devname(dev_t(bitPattern: info.e_tdev), mode_t(S_IFCHR)) {
            let name = String(cString: cname)
            if !name.isEmpty, name != "??" { return "/dev/\(name)" }
        }
        for descriptor in [Int32(0), 1, 2] where isatty(descriptor) != 0 {
            if let name = ttyname(descriptor) { return String(cString: name) }
        }
        return nil
    }
}
