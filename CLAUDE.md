# CLAUDE.md

Guidance for working in this repository.

## What this is

Orca is a macOS menu bar app that surfaces AI agents running across multiple
terminals (Claude Code, other CLI agents, ollama) in one place, shows how long
each has been working, notifies on state changes, and jumps to the owning
terminal on click. It exists to reduce context-switching when multitasking.

## Layout

Two independent Swift packages, each split into a Core library (testable, no UI
or `@main`) plus a thin executable, plus a test target.

```
app/                                 # the menu bar app (executable: Orca)
  Sources/OrcaCore/              # library — all testable logic
    AgentEvent.swift                 #   wire protocol (decode)
    Agent.swift                      #   Agent + AgentStatus models
    AgentStore.swift                 #   observable state (injected clock + notifier)
    NotificationScheduling.swift     #   notifier protocol (DIP)
    SocketServer.swift               #   unix socket listener
    OllamaPoller.swift               #   /api/ps polling
    TerminalActivating.swift         #   Strategy: per-terminal activators + focuser
  Sources/Orca/                  # executable — UI + wiring only
    OrcaApp.swift                #   @main App + AppDelegate (status item, popover)
    MenuView.swift                   #   SwiftUI dropdown
    StatusBarIcon.swift              #   composite dolphin + running/open badge
    DolphinAsset.swift               #   base64 template icon (generated)
    UserNotificationScheduler.swift  #   concrete NotificationScheduling
  Tests/OrcaCoreTests/
  Info.plist, AppIcon.icns

bridge/                              # the `orca` CLI (executable: orca)
  Sources/OrcaBridgeCore/        # library — all testable logic
    AgentEvent.swift                 #   wire protocol (encode)
    SocketClient.swift               #   send events to the app
    TerminalIdentity.swift           #   resolve tty / term program / bundle id
    ClaudeTranscript.swift           #   derive session name from transcript
    ArgumentParser.swift             #   --flag parsing
    HookInstaller.swift              #   merge/remove hooks in settings.json
    EventBuilder.swift               #   build events from flags + hook payload
  Sources/orca/main.swift        # executable — thin command dispatch (IO)
  Tests/OrcaBridgeCoreTests/

adapters/    Claude Code hook snippet, shell wrap helper
scripts/     bundle.sh, dev-install.sh, release.sh
install.sh   end-user installer (downloads a GitHub release)
```

## Build, test, lint

```sh
make all              # bundle build/Orca.app + build/orca
make run              # launch the app
make test             # swift test in both packages
make lint             # swiftlint  (brew install swiftlint)
make format           # swiftformat (brew install swiftformat)
```

Both packages build with plain SwiftPM (`swift build` / `swift test`). The app
bundle is assembled by `scripts/bundle.sh` (no Xcode project); `Info.plist` and
`AppIcon.icns` are copied in and the bundle is ad-hoc signed.

## Wire protocol

The bridge and app each define an `AgentEvent` (kept in sync). It is sent as one
line of JSON over the unix socket at
`~/Library/Application Support/Orca/orca.sock`:

```json
{"id":"...","source":"claude-code","title":"...","cwd":"/path",
 "status":"running|waiting|done|error|idle|closed","message":"...","ts":0,
 "tty":"/dev/ttys003","term_program":"iTerm.app","app_bundle_id":"...","session":"..."}
```

`closed`/`ended` remove the agent. `running` starts a run timer; leaving `running`
freezes the last run duration.

## Extending

- **New terminal for click-to-focus:** add a `TerminalActivator` implementation
  in `TerminalActivating.swift` and include it in `TerminalFocuser.defaultActivators`.
- **New agent source:** call `orca event --source <name> ...` from a hook or
  script, or write a JSON line to the socket. No app changes needed.
- **Claude session naming:** priority lives in `ClaudeTranscript` (rename >
  ai-title > summary > first user message).

## Conventions

- Swift, 4-space indent, 120-col soft limit (see `.swiftformat` / `.swiftlint.yml`).
- English only (code, comments, UI, docs).
- Comments explain *why*, not *what* — add them only where intent is non-obvious.
- Keep logic in the Core libraries so it stays unit-testable; keep the executables
  thin (UI, wiring, IO). Inject collaborators (clock, notifier, identity, paths)
  rather than reaching for globals, so tests can substitute them.
- Add or update tests when changing Core behavior; run `make test` before finishing.
