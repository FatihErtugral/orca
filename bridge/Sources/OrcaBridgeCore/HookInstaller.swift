import Foundation

/// Merges (and removes) Orca's Claude Code hooks in `settings.json` without
/// disturbing the user's other settings or hooks. The settings path and the
/// executable path are injectable so the merge can be tested against a temp file.
public struct HookInstaller {
    public let settingsPath: String
    public let executablePath: String

    public init(
        settingsPath: String = HookInstaller.defaultSettingsPath,
        executablePath: String = Bundle.main.executablePath ?? "orca"
    ) {
        self.settingsPath = settingsPath
        self.executablePath = executablePath
    }

    public static var defaultSettingsPath: String {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
            .path
    }

    public func hooks() -> [(event: String, command: String)] {
        [
            ("SessionStart", "\(executablePath) event --source claude-code --status running"),
            ("UserPromptSubmit", "\(executablePath) event --source claude-code --status running"),
            ("Notification", "\(executablePath) event --source claude-code --status waiting --message 'Waiting for your input'"),
            ("Stop", "\(executablePath) event --source claude-code --status waiting --message 'Response ready, your turn'"),
            ("SessionEnd", "\(executablePath) event --source claude-code --status closed")
        ]
    }

    @discardableResult
    public func install() -> Bool {
        var root = loadSettings()
        var hooksMap = root["hooks"] as? [String: Any] ?? [:]
        for (event, command) in hooks() {
            var entries = (hooksMap[event] as? [[String: Any]] ?? []).filter { !isOrcaEntry($0) }
            entries.append(["hooks": [["type": "command", "command": command]]])
            hooksMap[event] = entries
        }
        root["hooks"] = hooksMap
        return writeSettings(root)
    }

    @discardableResult
    public func uninstall() -> Bool {
        var root = loadSettings()
        guard var hooksMap = root["hooks"] as? [String: Any] else { return true }
        for (event, _) in hooks() {
            guard var entries = hooksMap[event] as? [[String: Any]] else { continue }
            entries = entries.filter { !isOrcaEntry($0) }
            if entries.isEmpty { hooksMap.removeValue(forKey: event) } else { hooksMap[event] = entries }
        }
        if hooksMap.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooksMap }
        return writeSettings(root)
    }

    private func loadSettings() -> [String: Any] {
        guard
            let data = FileManager.default.contents(atPath: settingsPath),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [:] }
        return object
    }

    private func writeSettings(_ root: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }
        let directory = (settingsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return (try? data.write(to: URL(fileURLWithPath: settingsPath))) != nil
    }

    private func isOrcaEntry(_ entry: [String: Any]) -> Bool {
        let inner = entry["hooks"] as? [[String: Any]] ?? []
        return inner.contains { ($0["command"] as? String)?.contains("orca event") == true }
    }
}
