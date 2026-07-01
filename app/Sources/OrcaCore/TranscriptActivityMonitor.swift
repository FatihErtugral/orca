import Foundation

/// Ground-truth "is Claude actually working?" signal for a session transcript.
public protocol TranscriptActivityTracking {
    /// Mark the current end of the transcript as the baseline; only records
    /// appended after this point count as activity.
    func rebaseline(_ path: String)
    func lastMeaningfulActivity(_ path: String) -> Date?
}

/// Reads only the bytes appended since the last look and counts a write as
/// activity only when it contains real work records (assistant/user turns).
/// Metadata appends — /rename (agent-name), ai-title, summaries, snapshots —
/// do not count, so they can't fake a running session.
public final class TranscriptActivityMonitor: TranscriptActivityTracking {
    private static let meaningfulTypes: Set<String> = ["assistant", "user"]
    private let maxReadBytes = 2_000_000

    private var offsets: [String: UInt64] = [:]
    private var lastMeaningful: [String: Date] = [:]

    public init() {}

    public func rebaseline(_ path: String) {
        offsets[path] = fileSize(path) ?? 0
        lastMeaningful.removeValue(forKey: path)
    }

    public func lastMeaningfulActivity(_ path: String) -> Date? {
        guard let size = fileSize(path) else { return lastMeaningful[path] }
        guard let baseline = offsets[path] else {
            offsets[path] = size
            return lastMeaningful[path]
        }
        guard size > baseline, let handle = FileHandle(forReadingAtPath: path) else {
            return lastMeaningful[path]
        }
        defer { try? handle.close() }

        try? handle.seek(toOffset: baseline)
        let data = handle.readData(ofLength: min(Int(size - baseline), maxReadBytes))

        // Only consume complete lines; a partially-written record stays for the
        // next pass instead of being skipped forever.
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return lastMeaningful[path] }
        offsets[path] = baseline + UInt64(lastNewline + 1)

        let complete = data.prefix(through: lastNewline)
        if containsMeaningfulRecord(complete) {
            lastMeaningful[path] = modificationDate(path) ?? Date()
        }
        return lastMeaningful[path]
    }

    private func containsMeaningfulRecord(_ data: Data) -> Bool {
        for line in data.split(separator: 0x0A) {
            guard
                let object = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                let type = object["type"] as? String
            else { continue }
            if Self.meaningfulTypes.contains(type) { return true }
        }
        return false
    }

    private func fileSize(_ path: String) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? UInt64
    }

    private func modificationDate(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
}
