# Orca 🐬

A macOS menu bar app that surfaces the AI agents running across your terminals
(Claude Code, other CLI agents, and local LLMs like ollama) in one place — so
multitasking across many sessions stops being a context-switching mess.

- **Menu bar app** (`app/`) — SwiftUI/AppKit `NSStatusItem` + `NSPopover`. Lists
  every agent, shows how long each has been working, notifies on
  `waiting` / `error`, and shows a framed `running/open` badge (e.g. `2/4`) next
  to the icon. Click an agent to jump to the terminal window/tab it runs in.
- **Bridge CLI** (`bridge/`) — `orca`. The single binary adapters call. It
  forwards events to the app over a unix domain socket; if the app is not
  running it does nothing (your agent never breaks).

## Quick Start

One command — no clone, no Xcode (auto-detects Apple Silicon / Intel):

```sh
curl -fsSL https://raw.githubusercontent.com/FatihErtugral/orca/main/install.sh | bash
```

While the repo is private, use the GitHub CLI instead (after `gh auth login`):

```sh
gh api repos/FatihErtugral/orca/contents/install.sh \
  -H "Accept: application/vnd.github.raw" | bash
```

Either one downloads the matching **Orca.app** release, copies it to
`/Applications`, clears the Gatekeeper quarantine, installs the `orca` CLI to
`~/.local/bin`, adds the Claude Code hooks, and launches. Grant the notification
prompt on first launch (and the Automation prompt the first time you jump to a
terminal). To clone and build from source instead, use `./scripts/dev-install.sh`.

## Architecture

```
[claude] --hooks-->  orca ---\
[aider]  --wrap--->  orca ----+--> unix socket --> Orca.app (menu bar)
[ollama] ------------- poll ------/
```

Both packages are split into a testable Core library and a thin executable. See
[CLAUDE.md](CLAUDE.md) for the full layout and extension points.

### Event protocol

One line of JSON per event, sent to the socket:

```json
{"id":"...","source":"claude-code","title":"...","cwd":"/path",
 "status":"running|waiting|done|error|idle|closed","message":"...","ts":0,
 "tty":"/dev/ttys003","term_program":"iTerm.app","app_bundle_id":"...","session":"..."}
```

Adding a source is just calling `orca event --source <name> ...` or writing a
JSON line to the socket. The core never changes.

## Install

### User — see [Quick Start](#quick-start)

`install.sh` auto-detects your CPU and downloads `Orca-arm64.tar.gz` or
`Orca-x86_64.tar.gz` from the latest release (via `gh` when available, plain
`curl` otherwise). Arch-specific scripts also exist: `install-arm64.sh`,
`install-intel.sh`.

### Maintainer — publish a release

```sh
./scripts/release.sh v0.3.0     # builds per-arch tarballs + creates the gh release
```

The tag must match `OrcaVersion.current` and `Info.plist` (the script enforces
this). Releases are ad-hoc signed; the installers strip quarantine so no
notarization is needed. For wide public distribution, an Apple Developer ID +
notarization is recommended.

### Developer (cloned repo, Xcode installed)

```sh
./scripts/dev-install.sh        # build + install + hooks + launch
```

## Connecting sources

**Claude Code** — run `orca install-hooks` (or add
`adapters/claude-code/settings.snippet.json`'s `hooks` block to
`~/.claude/settings.json`). The hooks map:
`UserPromptSubmit`/`SessionStart` → running, `Notification`/`Stop` → waiting,
`SessionEnd` → closed. The bridge reads `session_id`, `cwd`, and
`transcript_path` from the hook payload, and uses the session's own name (from
its transcript) as the title.

**Generic CLI commands** — `source adapters/shell/orca-wrap.sh` in your shell
rc, then:

```sh
ab aider            # run aider, monitored
ab -- npm run build # any command
```

**ollama** — automatic. The app polls `http://localhost:11434/api/ps` for running
models.

## Auto-update

Orca checks for new releases at launch and every 6 hours (via your `gh` auth).
When one is available the popover shows an **Update to vX.Y.Z** button — click it
and Orca downloads the release for your CPU, replaces the app and CLI, and
relaunches itself. You can also update from the terminal:

```sh
orca update            # update now
orca update --check    # only report
```

## Behavior notes

- **Badge:** `running/open` — left is agents actively working, right is open
  (live) sessions. Both stay accurate as sessions start, finish, and close.
- **Duration:** ticks only while running; when a run finishes it freezes at that
  run's duration, and a new run starts from zero.
- **Jump to terminal:** Terminal.app / iTerm2 focus the exact tab by `tty`;
  VS Code / Cursor / Windsurf / VSCodium focus the project window via the editor's
  URL scheme; other terminals are brought to the front.

## Development

```sh
make test     # unit + E2E tests for both packages
make lint     # swiftlint  (brew install swiftlint)
make format   # swiftformat (brew install swiftformat)
```

## Roadmap

- [x] Menu bar UI, event protocol, socket, bridge CLI, notifications
- [x] Claude Code / wrap / ollama adapters, session names
- [x] Running duration + running/open badge, click-to-terminal
- [x] Modular Core libraries with unit + E2E tests
- [x] Universal release + one-line installer
- [ ] Launch at login (LaunchAgent)
- [ ] Developer ID signing + notarization

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — you may use, modify and share Orca
for any **noncommercial** purpose. Commercial use of the software is not
permitted without a separate license from the copyright holder.
