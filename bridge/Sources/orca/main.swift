import OrcaBridgeCore
import Foundation
#if canImport(Darwin)
import Darwin
#endif

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Claude Code hooks pipe a JSON payload on stdin. Poll briefly instead of
/// blocking so manual invocations with an open-but-silent stdin never hang.
func readHookPayload() -> [String: Any]? {
    let fd = FileHandle.standardInput.fileDescriptor
    guard isatty(fd) == 0 else { return nil }

    var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
    guard poll(&pollFD, 1, 300) > 0, pollFD.revents & Int16(POLLIN) != 0 else { return nil }

    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

func runEvent(_ args: [String]) -> Int32 {
    let parsed = ArgumentParser.parse(args)
    let event = EventBuilder().event(flags: parsed.flags, hook: readHookPayload())
    deliver(event)
    return 0
}

let stateStore = AgentStateStore()

/// Send to the running app and persist the open-session state for launch discovery.
func deliver(_ event: AgentEvent) {
    SocketClient().send(event)
    stateStore.record(event)
}

func runWrap(_ args: [String]) -> Int32 {
    let parsed = ArgumentParser.parse(args)
    guard let executable = parsed.rest.first else {
        printError("usage: orca wrap [--source S] [--title T] -- <command> [args...]")
        return 2
    }

    let builder = EventBuilder()
    let name = (executable as NSString).lastPathComponent
    let id = "wrap:\(name):\(getpid())"
    let source = parsed.flags["source"] ?? "custom"
    let title = parsed.flags["title"] ?? name
    let cwd = FileManager.default.currentDirectoryPath

    func emit(_ status: String, _ message: String?) {
        deliver(builder.wrapEvent(id: id, source: source, title: title, cwd: cwd, status: status, message: message))
    }

    emit("running", nil)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = parsed.rest
    do {
        try process.run()
    } catch {
        emit("error", "failed to start: \(error.localizedDescription)")
        return 127
    }
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        emit("done", nil)
    } else {
        emit("error", "exit code \(process.terminationStatus)")
    }
    return process.terminationStatus
}

func runInstallHooks() -> Int32 {
    let installer = HookInstaller()
    guard installer.install() else {
        printError("orca: failed to write \(installer.settingsPath)")
        return 1
    }
    print("orca: hooks installed -> \(installer.settingsPath)")
    print("(Restart Claude Code or open /hooks for them to take effect.)")
    return 0
}

func runUninstallHooks() -> Int32 {
    let installer = HookInstaller()
    guard installer.uninstall() else {
        printError("orca: failed to write \(installer.settingsPath)")
        return 1
    }
    print("orca: hooks removed")
    return 0
}

// MARK: - Update

@discardableResult
func run(_ executable: String, _ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do { try process.run() } catch { return (127, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
}

func findGH() -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = ["\(home)/.local/bin/gh", "/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
    if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return found }
    let which = run("/usr/bin/which", ["gh"])
    return which.status == 0 && !which.output.isEmpty ? which.output : nil
}

func machineArch() -> String {
    var uts = utsname()
    uname(&uts)
    return withUnsafeBytes(of: &uts.machine) { raw in
        String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
    }
}

func runUpdate(_ args: [String]) -> Int32 {
    let parsed = ArgumentParser.parse(args)
    let checkOnly = parsed.flags["check"] != nil
    let current = parsed.flags["current"] ?? OrcaVersion.current

    guard let gh = findGH() else {
        printError("orca: 'gh' not found — install it (brew install gh) and run 'gh auth login'.")
        return 1
    }
    let latest = run(gh, ["api", "repos/\(OrcaVersion.repo)/releases/latest", "--jq", ".tag_name"])
    guard latest.status == 0, !latest.output.isEmpty else {
        printError("orca: could not reach GitHub (is 'gh auth login' done?)")
        return 1
    }
    let tag = latest.output

    guard OrcaVersion.isNewer(tag, than: current) else {
        print("orca is up to date (v\(current))")
        return 0
    }
    if checkOnly {
        print("update-available \(tag)")
        return 0
    }

    print("==> Updating v\(current) -> \(tag)")
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let tmp = NSTemporaryDirectory() + "orca-update-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmp) }

    let asset = "Orca-\(machineArch()).tar.gz"
    print("==> Downloading \(asset)")
    guard run(gh, ["release", "download", tag, "--repo", OrcaVersion.repo,
                   "--pattern", asset, "--dir", tmp, "--clobber"]).status == 0 else {
        printError("orca: download failed")
        return 1
    }
    guard run("/usr/bin/tar", ["-xzf", "\(tmp)/\(asset)", "-C", tmp]).status == 0 else {
        printError("orca: extract failed")
        return 1
    }

    print("==> Installing Orca.app")
    let appDest = "/Applications/Orca.app"
    try? FileManager.default.removeItem(atPath: appDest)
    guard run("/bin/cp", ["-R", "\(tmp)/Orca.app", appDest]).status == 0 else {
        printError("orca: could not replace \(appDest)")
        return 1
    }
    run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", appDest])

    print("==> Installing orca CLI")
    let cliDest = "\(home)/.local/bin/orca"
    // Unlink first: overwriting a running executable in place is unsafe.
    try? FileManager.default.removeItem(atPath: cliDest)
    run("/bin/cp", ["\(tmp)/orca", cliDest])
    run("/bin/chmod", ["+x", cliDest])

    print("==> Relaunching Orca")
    run("/usr/bin/pkill", ["-f", "Orca.app/Contents/MacOS/Orca"])
    Thread.sleep(forTimeInterval: 0.6)
    run("/usr/bin/open", [appDest])
    print("==> Updated to \(tag)")
    return 0
}

func printUsage() {
    print("""
    orca — Orca bridge (v\(OrcaVersion.current))

    Usage:
      orca event           --status <running|waiting|done|error|idle> [--source S] [--id ID] [--title T] [--cwd DIR] [--message M]
      orca wrap            [--source S] [--title T] -- <command> [args...]
      orca install-hooks   Add Orca's Claude Code hooks to ~/.claude/settings.json
      orca uninstall-hooks Remove Orca's hooks
      orca update          Update Orca.app and this CLI to the latest release
      orca update --check  Only report whether an update is available

    `event` also reads a Claude Code hook payload from stdin (session_id, cwd, transcript_path).
    """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    printUsage()
    exit(0)
}
let commandArgs = Array(arguments.dropFirst())

switch command {
case "event":
    exit(runEvent(commandArgs))
case "wrap":
    exit(runWrap(commandArgs))
case "install-hooks":
    exit(runInstallHooks())
case "uninstall-hooks":
    exit(runUninstallHooks())
case "update":
    exit(runUpdate(commandArgs))
case "--version", "version":
    print("orca v\(OrcaVersion.current)")
    exit(0)
case "-h", "--help", "help":
    printUsage()
    exit(0)
default:
    printError("orca: unknown command '\(command)'")
    printUsage()
    exit(2)
}
