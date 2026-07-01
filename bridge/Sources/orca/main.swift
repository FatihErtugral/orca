import OrcaBridgeCore
import Foundation
#if canImport(Darwin)
import Darwin
#endif

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Claude Code hooks pipe a JSON payload on stdin; read it only when stdin is a
/// pipe so interactive invocations don't block.
func readHookPayload() -> [String: Any]? {
    guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return nil }
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

func printUsage() {
    print("""
    orca — Orca bridge

    Usage:
      orca event           --status <running|waiting|done|error|idle> [--source S] [--id ID] [--title T] [--cwd DIR] [--message M]
      orca wrap            [--source S] [--title T] -- <command> [args...]
      orca install-hooks   Add Orca's Claude Code hooks to ~/.claude/settings.json
      orca uninstall-hooks Remove Orca's hooks

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
case "-h", "--help", "help":
    printUsage()
    exit(0)
default:
    printError("orca: unknown command '\(command)'")
    printUsage()
    exit(2)
}
