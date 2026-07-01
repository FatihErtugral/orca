import Combine
import Foundation

/// Periodically asks the `orca` CLI whether a newer release exists, and runs the
/// update detached (so it survives this app being replaced and relaunched).
final class UpdateMonitor: ObservableObject {
    enum CheckState: Equatable {
        case idle, checking, upToDate
        case installing(String)
    }

    @Published var availableVersion: String?
    @Published var checkState: CheckState = .idle

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
            guard let self = self else { return }
            let version = self.fetchAvailableVersion()
            DispatchQueue.main.async { self.availableVersion = version }
        }
    }

    /// Manual "Check for updates": reports up-to-date, or installs right away.
    func checkAndInstall() {
        guard checkState == .idle || checkState == .upToDate else { return }
        checkState = .checking
        queue.async { [weak self] in
            guard let self = self else { return }
            let version = self.fetchAvailableVersion()
            DispatchQueue.main.async {
                self.availableVersion = version
                if let version = version {
                    self.checkState = .installing(version)
                    self.installUpdate()
                } else {
                    self.checkState = .upToDate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.checkState == .upToDate { self.checkState = .idle }
                    }
                }
            }
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

    private func fetchAvailableVersion() -> String? {
        guard FileManager.default.isExecutableFile(atPath: cliPath) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["update", "--check"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.hasPrefix("update-available ")
            ? String(output.dropFirst("update-available ".count))
            : nil
    }
}
