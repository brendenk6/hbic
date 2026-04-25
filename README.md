# HBIC — Mac Control Skill for Claude Code

A Claude Code skill that gives Claude full control of macOS: mouse, keyboard, screenshots, window management, terminal orchestration, browser JS execution, AppleScript-aware apps (Notes / Calendar / Mail / Messages / Finder), accessibility tree reading, and notifications.

> "HBIC" = Head Bitch In Charge. Yes, really.

## What this skill is

`SKILL.md` is reference documentation Claude loads when it needs to drive the Mac. It's not a standalone tool — it documents the patterns and command surface of a custom toolkit.

The toolkit consists of two local CLIs (`hid` for input/vision/terminal, `cdb` for the claude.ai API) backed by a local HTTP service called **ClaudeDesktopBridge**. The bridge exposes mouse/keyboard/screen primitives over `127.0.0.1:8421` using kernel-level HID injection (`IOHIDPostEvent`) and Quartz framebuffer capture. The skill also documents fallbacks and complementary paths — `cliclick` for Electron/webview clicks (where IOHIDPostEvent doesn't register), AppleScript for menus and scriptable apps, and `osascript` System Events for the macOS accessibility tree.

## Prerequisites

To actually run the commands documented here, you need:

- macOS (tested on macOS 26 Tahoe)
- A local input/vision bridge listening on `127.0.0.1:8421` with mouse / keyboard / screen / window endpoints. The skill describes the API surface — implementations vary
- `~/bin/hid` and `~/bin/cdb` CLIs that talk to the bridge
- [`cliclick`](https://github.com/BlueM/cliclick) installed at `/opt/homebrew/bin/cliclick` for Electron / webview interaction
- macOS Accessibility and Screen Recording permissions granted to the bridge service and Terminal
- Optional: `kimi`, `gemini`, `codex` CLIs if you want the cross-LLM orchestration patterns

If you don't have a bridge service: the AppleScript / `osascript` / `cliclick` / `pbcopy` / `open` patterns in the skill all work standalone with no bridge — it's only the `hid <verb>` commands that need it.

## Using the skill with Claude Code

Drop this directory at `~/.claude/skills/hbic/` (or any `.claude/skills/` location). Claude Code auto-discovers skills there. Once installed, Claude will load `SKILL.md` automatically when the user asks Claude to click, type, take screenshots, drive an app, run JavaScript in a browser, send notifications, etc.

The frontmatter `description` field controls when Claude pulls the skill in. The skill is small enough to keep in context whenever Mac control is on the table.

## What's in `SKILL.md`

- **Mouse / Keyboard / Vision** — primitives via `hid`
- **Click Method Decision Tree** — when to use `hid click` vs `cliclick` vs accessibility API
- **Terminal** — orchestrating other Claude Code sessions, self-compact, cross-LLM CLIs
- **Apps via AppleScript** — Chrome/Safari JS execution (with the JS-from-Apple-Events toggle gotcha), native scriptable apps (Notes, Calendar, Mail, Messages, Finder), accessibility-tree reading, native notifications
- **System Primitives** — `open`, clipboard (`pbcopy`/`pbpaste`), process management, volume, window position
- **HTTP API** — full bridge endpoint reference
- **Patterns** — high-leverage workflows: cross-LLM orchestration intro, parallel work coordination, dismissing system permission dialogs, OCR-driven coordinate workflows
- **Key Details** — kernel paths, permission notes, known limits

## License

MIT.
