import Combine
import Foundation

/// Periodically asks the `orca` CLI whether a newer release exists, and runs the
/// update detached (so it survives this app being replaced and relaunched).
final class UpdateMonitor: ObservableObject {
    @Published var availableVersion: String?

    private var timer: Timer?
    private let queue = DispatchQueue(label: "orca.update.check", qos: .utility)

    private var cliPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin/orca"
    }

    func start(interval: TimeInterval = 6 * 3600) {
        check()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.check() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() {
        queue.async { [weak self] in
            guard let self = self, FileManager.default.isExecutableFile(atPath: self.cliPath) else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.cliPath)
            process.arguments = ["update", "--check"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let version = output.hasPrefix("update-available ")
                ? String(output.dropFirst("update-available ".count))
                : nil
            DispatchQueue.main.async { self.availableVersion = version }
        }
    }

    /// Launch the updater fully detached: it will kill this app and relaunch the
    /// new one, so it must not die with us.
    func installUpdate() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "nohup \"\(cliPath)\" update >/dev/null 2>&1 &"]
        try? process.run()
    }
}
