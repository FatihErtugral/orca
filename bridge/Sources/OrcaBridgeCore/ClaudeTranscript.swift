import Foundation

/// Derives a human-friendly session name from a Claude Code transcript, matching
/// what the `/resume` picker shows. Priority: explicit `/rename` > AI-generated
/// title > compaction summary > first user message.
public enum ClaudeTranscript {
    public static func sessionTitle(transcriptPath: String) -> String? {
        guard let content = try? String(contentsOfFile: transcriptPath, encoding: .utf8) else {
            return nil
        }
        return sessionTitle(fromContents: content)
    }

    public static func sessionTitle(fromContents content: String) -> String? {
        var renamed: String?
        var aiTitle: String?
        var summary: String?
        var firstUserMessage: String?

        for line in content.split(separator: "\n") {
            guard
                let data = line.data(using: .utf8),
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                let type = object["type"] as? String
            else { continue }

            switch type {
            case "agent-name":
                if let name = object["agentName"] as? String, !name.isEmpty { renamed = name }
            case "ai-title":
                if let title = object["aiTitle"] as? String, !title.isEmpty { aiTitle = title }
            case "summary":
                if let value = object["summary"] as? String, !value.isEmpty { summary = value }
            case "user" where firstUserMessage == nil:
                if let text = userText(object), isPlausibleTitle(text) { firstUserMessage = text }
            default:
                break
            }
        }

        guard let raw = renamed ?? aiTitle ?? summary ?? firstUserMessage else { return nil }
        return truncate(raw)
    }

    private static func userText(_ object: [String: Any]) -> String? {
        guard let message = object["message"] as? [String: Any] else { return nil }
        if let text = message["content"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let parts = message["content"] as? [[String: Any]] {
            let texts = parts.compactMap { part -> String? in
                (part["type"] as? String) == "text" ? part["text"] as? String : nil
            }
            let joined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func isPlausibleTitle(_ text: String) -> Bool {
        !text.isEmpty && !text.hasPrefix("<")
    }

    private static func truncate(_ text: String, limit: Int = 60) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        guard flat.count > limit else { return flat }
        let end = flat.index(flat.startIndex, offsetBy: limit)
        return String(flat[..<end]).trimmingCharacters(in: .whitespaces) + "…"
    }
}
