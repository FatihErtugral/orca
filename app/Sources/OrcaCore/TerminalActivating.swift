import AppKit
import Foundation

/// Strategy for bringing the terminal an agent runs in to the front. Each
/// terminal family provides its own activator; `TerminalFocuser` picks the first
/// one that can handle a given agent.
public protocol TerminalActivator {
    func canActivate(_ agent: Agent) -> Bool
    func activate(_ agent: Agent)
}

public struct TerminalFocuser {
    private let activators: [TerminalActivator]

    public init(activators: [TerminalActivator] = TerminalFocuser.defaultActivators) {
        self.activators = activators
    }

    public static var defaultActivators: [TerminalActivator] {
        [AppleTerminalActivator(), ITermActivator(), VSCodeFamilyActivator(), GenericAppActivator()]
    }

    public func focus(_ agent: Agent) {
        DispatchQueue.global(qos: .userInitiated).async {
            activators.first { $0.canActivate(agent) }?.activate(agent)
        }
    }
}

enum TerminalActivation {
    static func runAppleScript(_ source: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        try? process.run()
    }

    static func activateApp(bundleId: String) {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleId)
            .first?
            .activate(options: [.activateAllWindows])
    }
}

public struct AppleTerminalActivator: TerminalActivator {
    public init() {}

    public func canActivate(_ agent: Agent) -> Bool { agent.termProgram == "Apple_Terminal" }

    public func activate(_ agent: Agent) {
        guard let tty = agent.tty else {
            TerminalActivation.activateApp(bundleId: "com.apple.Terminal")
            return
        }
        TerminalActivation.runAppleScript("""
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        if tty of t is "\(tty)" then
                            set selected tab of w to t
                            set frontmost of w to true
                            return
                        end if
                    end try
                end repeat
            end repeat
        end tell
        """)
    }
}

public struct ITermActivator: TerminalActivator {
    public init() {}

    public func canActivate(_ agent: Agent) -> Bool { agent.termProgram == "iTerm.app" }

    public func activate(_ agent: Agent) {
        guard let tty = agent.tty else {
            TerminalActivation.activateApp(bundleId: "com.googlecode.iterm2")
            return
        }
        TerminalActivation.runAppleScript("""
        tell application "iTerm"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is "\(tty)" then
                                select w
                                select t
                                select s
                                return
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
        end tell
        """)
    }
}

/// VS Code / Cursor / Windsurf / VSCodium all report term_program "vscode" and
/// can't be focused per-tab, so we open the agent's folder via the editor's URL
/// scheme, which focuses the window already showing that workspace.
public struct VSCodeFamilyActivator: TerminalActivator {
    public init() {}

    public func canActivate(_ agent: Agent) -> Bool { agent.termProgram == "vscode" }

    public func activate(_ agent: Agent) {
        let bundleId = agent.appBundleId ?? "com.microsoft.VSCode"
        guard
            let cwd = agent.cwd,
            let scheme = Self.urlScheme(forBundleId: bundleId),
            let encoded = cwd.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "\(scheme)://file\(encoded)")
        else {
            TerminalActivation.activateApp(bundleId: bundleId)
            return
        }
        if !NSWorkspace.shared.open(url) {
            TerminalActivation.activateApp(bundleId: bundleId)
        }
    }

    static let knownSchemes: [String: String] = [
        "com.microsoft.VSCode": "vscode",
        "com.microsoft.VSCodeInsiders": "vscode-insiders",
        "com.vscodium.codium": "vscodium",
        "com.exafunction.windsurf": "windsurf"
    ]

    public static func urlScheme(forBundleId bundleId: String) -> String? {
        if let scheme = knownSchemes[bundleId] { return scheme }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let guess = appURL.deletingPathExtension().lastPathComponent
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
            if !guess.isEmpty { return guess }
        }
        return nil
    }
}

public struct GenericAppActivator: TerminalActivator {
    public init() {}

    public func canActivate(_ agent: Agent) -> Bool { true }

    public func activate(_ agent: Agent) {
        if let bundleId = Self.bundleId(for: agent.termProgram) {
            TerminalActivation.activateApp(bundleId: bundleId)
        }
    }

    static let bundleIds: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "vscode": "com.microsoft.VSCode",
        "ghostty": "com.mitchellh.ghostty",
        "WezTerm": "com.github.wez.wezterm",
        "Hyper": "co.zeit.hyper",
        "Tabby": "org.tabby"
    ]

    public static func bundleId(for termProgram: String?) -> String? {
        guard let termProgram = termProgram else { return nil }
        return bundleIds[termProgram]
    }
}
