---
description: HBIC — full Mac control + self-management. Mouse, keyboard, screenshots, window management, terminal, browsers (Chrome/Safari JS-execute), AppleScript-aware apps (Notes/Calendar/Mail/Messages/Finder), accessibility tree, notifications, self-compact, cross-LLM orchestration. Use when user asks to click, type, take screenshots, move the mouse, find windows, drive any Mac app, send notifications, run JavaScript in a browser, compact sessions, or control other LLMs.
---

# HBIC — Mac Control (CDB HID + Vision + Terminal)

All commands go through ClaudeDesktopBridge at `127.0.0.1:8421`. Auth token at `~/.config/claude-desktop-bridge/token`.

Two CLIs: `~/bin/hid` for input/vision/terminal, `~/bin/cdb` for claude.ai API.

## Mouse

```bash
hid pos                        # current mouse x y
hid screen                     # screen width height
hid move <x> <y>              # absolute mouse move
hid click <x> <y>             # left click
hid rclick <x> <y>            # right click
hid dclick <x> <y>            # double click
hid drag <x1> <y1> <x2> <y2> # drag from to
hid scroll <dy> [dx]           # scroll (negative = down)
```

## Keyboard

```bash
hid type <text>                # type text string
hid key <combo>                # key combo (cmd+c, shift+cmd+4, return)
hid down <combo>               # key down (hold)
hid up <combo>                 # key up (release)
```

## Vision (Screenshots + Windows)

```bash
hid capture [file]             # full screenshot (default /tmp/cdb_screen.png)
hid region <x> <y> <w> <h> [file]  # capture region
hid windows                    # list all on-screen windows (ID, app, size, title)
hid windows find <app>         # find windows by app name
hid wcapture <window_id> [file]  # capture specific window
```

## Click Method

| Target | Tool | Why |
|--------|------|-----|
| Native macOS apps, Terminal, Finder | `hid click <x> <y>` | IOHIDPostEvent works on native UI |
| Electron / web apps (Codex, ChatGPT, Slack, VS Code, Discord) | `cliclick c:<x>,<y>` | IOHIDPostEvent doesn't register on webview elements |
| macOS system permission dialogs | Accessibility API via `osascript` | Both hid and cliclick blocked |
| Menu bar items (any app) | `osascript ... click menu item ...` | Menus are AX-only |
| Browser page content (Chrome / Safari) | JS execute via AppleScript | Faster and pixel-independent |

```bash
/opt/homebrew/bin/cliclick c:<x>,<y>          # click
/opt/homebrew/bin/cliclick dc:<x>,<y>         # double-click
/opt/homebrew/bin/cliclick rc:<x>,<y>         # right-click
/opt/homebrew/bin/cliclick kp:return          # press Enter
/opt/homebrew/bin/cliclick t:'text'           # type ASCII (no newlines, no special chars)
```

For complex text (newlines, multi-line, non-ASCII): `pbcopy` then `cmd+v` paste.

## Terminal

### Discovery & Control

```bash
hid term                       # list all terminal windows + tabs + TTYs + processes
hid term claude                # find claude code sessions (window ID + TTY + name)
hid term new                   # open new terminal window
hid term focus <window_id>     # bring window to front
hid term compact <window_id>   # focus + type /compact + enter
```

### Run a command in a new Terminal window

```bash
osascript <<'APPLESCRIPT'
tell application id "com.apple.Terminal"
  activate
  do script "cd /path/to/project && your-command-here"
end tell
APPLESCRIPT
```

### Send a message to an existing Terminal window

```bash
pbcopy <<'PROMPT'
your prompt here — any length, any characters
PROMPT

osascript <<'APPLESCRIPT'
tell application id "com.apple.Terminal"
  activate
  set index of window id <wid> to 1
end tell
delay 0.2
tell application "System Events"
  tell process "Terminal"
    keystroke "v" using command down
    key code 36
  end tell
end tell
APPLESCRIPT
```

### Verify delivery

Paste+enter can silently fail. Always verify after sending:
```bash
sleep 3
hid wcapture <wid> /tmp/verify_send.png
```
Read the screenshot to confirm. If unsubmitted text is sitting at the prompt (Gemini shows "[Pasted Text: N lines]"), press Return again:
```bash
osascript -e 'tell application "Terminal" to set index of window id <wid> to 1'
sleep 0.5
osascript -e 'tell application "System Events" to tell process "Terminal" to key code 36'
```

### Read terminal output

```bash
osascript -e 'tell application "Terminal" to return history of tab 1 of window id <wid>' | tail -30
```

## Cross-LLM Orchestration

### Start an LLM

Available CLIs: `kimi`, `gemini`, `codex`, `claude`.
```bash
osascript <<'APPLESCRIPT'
tell application id "com.apple.Terminal"
  activate
  do script "kimi"
end tell
APPLESCRIPT
```
Or `~/bin/llms <name>`. Wait a few seconds for boot, then `hid term` to get the window ID.

### Introduce yourself (every time, before the task)

Find your own window ID first: `hid term claude`, match by TTY via `ps -o tty= -p $PPID`.

Paste this intro using the Terminal messaging pattern:

1. **Identity** — your name, model, your terminal window ID
2. **Chain of command** — Brenden is the user with final authority, you are coordinating
3. **Reply method** — tell them to load `~/.claude/skills/hbic/SKILL.md` and reply via the AppleScript clipboard pattern aimed at your window ID
4. **Then the task**

### Monitor (mandatory — always loop back)

After sending a message to another LLM, **set up a ScheduleWakeup or /loop to check their response.** Never end your turn with a status update to Brenden.

- First checks at 60-120s — verify they understood, have permissions, aren't off-track
- Once on track, space out to 120-270s
- Read their terminal history each check: `osascript -e 'tell application "Terminal" to return history of tab 1 of window id <wid>' | tail -50`
- Screenshot if history is ambiguous: `hid wcapture <wid> /tmp/check.png`
- If stuck → inspect the problem yourself, send hints with context
- If wrong direction → redirect clearly: "Stop working on X, focus on Y instead"
- If burning context on polish → tell them to ship what they have

### Interrupt mid-generation

```bash
osascript -e 'tell application "Terminal" to set frontmost of window id <wid> to true' \
          -e 'tell application "System Events" to keystroke "s" using control down'
```
Sends ctrl-s (LLM CLIs recognize as "send immediately"). For Claude: `Ctrl+B` interrupts and forces processing queued input. `Esc` twice cancels generation.

### Parallel work rules

1. Agree on file ownership before coding — no two agents edit the same file
2. Wait for acknowledgment before starting work
3. State claimed files explicitly
4. Message before touching a file another agent owns
5. Report what you changed after finishing

### LLM Memory Files

| CLI | File |
|-----|------|
| Claude | `~/.claude/CLAUDE.md` |
| Kimi | `~/KIMI.md` (own memory between `KIMI_OWN_MEMORY_START/END` markers, sync appends after) |
| Gemini | `~/.gemini/GEMINI.md` |
| Codex | `~/.codex/AGENTS.md` |

Sync script: `~/.claude/projects/<project-id>/memory/scripts/sync_external_clis.py` propagates Claude context into all CLI files after `scripts/index.py` runs.

## Apps via AppleScript

### Browser control (Chrome / Safari)

List all tabs:
```bash
osascript -e 'tell application "Google Chrome"
  set out to ""
  repeat with w in windows
    repeat with t in tabs of w
      set out to out & (title of t) & " :: " & (URL of t) & linefeed
    end repeat
  end repeat
  return out
end tell'
```

Active tab:
```bash
osascript -e 'tell application "Google Chrome" to URL of active tab of front window'
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://..."'
open -a "Google Chrome" "https://..."
```

Execute JS in any tab:
```bash
osascript -e 'tell application "Google Chrome" to execute active tab of front window javascript "document.title"'
```

Chrome JS execution is OFF by default per session. Toggle ON:
```bash
osascript -e 'tell application "Google Chrome" to activate' \
          -e 'tell application "System Events" to tell process "Google Chrome" to click menu item "Allow JavaScript from Apple Events" of menu 1 of menu item "Developer" of menu 1 of menu bar item "View" of menu bar 1'
```

Safari:
```bash
osascript -e 'tell application "Safari" to do JavaScript "document.title" in current tab of front window'
```

JS results return as strings — wrap complex data in `JSON.stringify(...)`.

### Native AppleScript-aware apps

Drive these as data, not pixels. Open Script Editor → File → Open Dictionary for full API.

```bash
# Notes
osascript -e 'tell application "Notes" to make new note at folder "Notes" with properties {name:"Title", body:"<b>Body HTML</b>"}'

# Reminders
osascript -e 'tell application "Reminders" to make new reminder with properties {name:"Pick up groceries", due date:date "Saturday, April 25, 2026 5:00 PM"}'

# Calendar
osascript -e 'tell application "Calendar" to tell calendar "Home" to make new event with properties {summary:"Meeting", start date:(current date), end date:(current date) + 1 * hours}'

# Messages
osascript -e 'tell application "Messages" to send "Hi" to buddy "+15551234567" of (service 1 whose service type is iMessage)'

# Mail
osascript -e 'tell application "Mail" to make new outgoing message with properties {subject:"...", content:"...", visible:true}'

# Finder
open -R /path/to/file
```

### Accessibility tree

Works on any app, faster than screenshot+OCR for labeled elements.

```bash
osascript -e 'tell application "System Events" to tell process "App Name" to entire contents of window 1'
osascript -e 'tell application "System Events" to tell process "App Name" to click (first button whose name is "Submit") of window 1'
osascript -e 'tell application "System Events" to tell process "App Name" to value of text field 1 of window 1'
osascript -e 'tell application "System Events" to tell process "App Name" to set value of text field 1 of window 1 to "hello"'
```

### Notifications

```bash
osascript -e 'display notification "Build done" with title "Claude" sound name "Glass"'
osascript -e 'display notification "Tests failed: 3" with title "Claude" subtitle "Math 148" sound name "Basso"'
```
Sounds: Glass, Basso, Blow, Bottle, Frog, Funk, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink.

Modal (blocks until dismissed):
```bash
osascript -e 'display dialog "Need confirmation?" buttons {"No", "Yes"} default button "Yes"'
```

## System Primitives

### `open`
```bash
open -a "Google Chrome" "https://example.com"
open -a Specter
open /path/to/file.pdf
open -R /path/to/file
open -e file.txt
```

### Clipboard
```bash
pbcopy < file.txt
echo "text" | pbcopy
pbpaste
pbpaste > out.txt
```

For long/complex text into any app:
```bash
echo "complex text" | pbcopy
hid click <x> <y>
hid key cmd+v
```

### Process management
```bash
pgrep -l "Google Chrome"
pgrep -lf "specific command line"
pkill -f "App Name"
killall "App Name"
```

### Volume / display
```bash
osascript -e 'set volume output volume 50'     # 0-100
osascript -e 'set volume with output muted'
osascript -e 'set volume without output muted'
pmset displaysleepnow
caffeinate -d -t 3600
```

### Window position and size
```bash
osascript -e 'tell application "System Events" to tell process "App Name" to set position of window 1 to {0, 0}'
osascript -e 'tell application "System Events" to tell process "App Name" to set size of window 1 to {1200, 800}'
```

## HTTP API

All endpoints need `Authorization: Bearer <token>` header.

```
GET  /mouse/position
POST /mouse/move          {"x": 100, "y": 200}
POST /mouse/click         {"x": 100, "y": 200}
POST /mouse/doubleclick   {"x": 100, "y": 200}
POST /mouse/rightclick    {"x": 100, "y": 200}
POST /mouse/drag          {"from_x": 0, "from_y": 0, "to_x": 100, "to_y": 100}
POST /mouse/scroll        {"dy": -3, "dx": 0}

POST /keyboard/type       {"text": "hello"}
POST /keyboard/press      {"keys": "cmd+c"}
POST /keyboard/down       {"keys": "shift"}
POST /keyboard/up         {"keys": "shift"}

GET  /screen/size
GET  /screen/capture
POST /screen/capture/region  {"x": 0, "y": 0, "width": 500, "height": 500}

GET  /windows
POST /windows/search      {"app": "Terminal"}
POST /windows/capture     {"window_id": 1234}

GET  /terminal/claude
POST /terminal/compact    {"window_id": 1234}
```

## Patterns

### Click a UI element
1. `hid windows find <App>` → get window position
2. `hid capture` → see what's on screen
3. Calculate coordinates from screenshot + window bounds
4. `hid click <x> <y>` (native) or `cliclick c:<x>,<y>` (Electron)

### Type into an app
1. `hid click <x> <y>` to focus the field
2. `hid type "text"` for short text, or `pbcopy` + `hid key cmd+v` for long/complex

### Compact another Claude session
1. `hid term claude` → list sessions
2. `hid term compact <window_id>`

### Self-compact
1. `hid term claude` → find your own window ID (match by TTY via `ps -o tty= -p $PPID`)
2. `hid term compact <your_window_id>`
3. Send as the LAST action before your response ends (only works when idle at input prompt)

### Web forms (one-shot / rate-limited)

1. **Verify before submitting.** Many platforms cap attempts. Read the form via JS before clicking Submit.
2. **Multi-tab forms: fill every tab before submitting.** A single Submit usually covers all tabs.
3. **Read dropdown options before filling.** Exact spelling matters — query the data layer.

Navigation gotchas:
- Resume splash pages between re-entry and the question
- Next-button can skip 2 items during a save — verify location after navigation
- Duplicate-tab errors from clicking LMS links while prior session loads

### Dismissing macOS permission dialogs

```bash
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Allow" of window 1'
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to return entire contents of window 1'
```

### Codex (OpenAI) desktop app

App is Electron (bundle id `com.openai.codex`). Two binaries:
- `/Applications/Codex.app/Contents/Resources/codex` — Rust, current with app
- `~/.npm-global/bin/codex` — Node wrapper, may be older

IPC into running app:
```bash
/Applications/Codex.app/Contents/Resources/codex app-server proxy
/Applications/Codex.app/Contents/Resources/codex app-server generate-json-schema
```

CLI subcommands: `exec "..."` (one-shot), `resume --last`, `fork --last`, `apply` (git apply last diff), `review`, `cloud`, `mcp-server`, `sandbox`.

Common flags: `-c model=gpt-5.5`, `-m gpt-5.5`, `--full-auto`, `-s {read-only,workspace-write,danger-full-access}`, `--search`, `-i image.png`, `-C dir`.

App notes:
- Modes per thread: Local / Worktree / Cloud (Cloud is separate usage bucket)
- `$imagegen` triggers gpt-image-2
- Shortcuts: `Cmd+J` terminal, `Cmd+K` command palette, `Ctrl+M` voice, `Ctrl+L` clear terminal
- 1M context toggle gone in GPT-5.5 — use 5.4 if needed
- Electron: clicks require `cliclick`

### Pixel coordinates via Prism vision encoder

```python
from prism.ascii_vision import encode_screenshot, _ocr_vision_framework
text, spatial, ui_elements, ocr_texts = encode_screenshot('/tmp/screenshot.png', ocr=True, fullmap=True)
regions = _ocr_vision_framework('/tmp/screenshot.png')  # quick OCR only
```

Coordinates are Retina 2x. Convert: `screen_x = img_x // 2`, `screen_y = img_y // 2`. For window captures, add window origin.

## Key Details

- Mouse: `CGWarpMouseCursorPosition` (absolute, no permission needed)
- Clicks/keys: `IOHIDPostEvent` (kernel HID). Accessibility permission GRANTED. Screen Recording enabled.
- IOHIDPostEvent clicks do NOT work on Electron — use `cliclick`
- Screenshots: `CGDisplayCreateImage` (direct framebuffer). Do NOT capture the Dock.
- Window capture falls back to region crop without Screen Recording permission
- Terminal commands (`hid term *`) use AppleScript directly from shell, NOT through the HTTP service
- Service runs as launchd agent: `com.brenden.claude-desktop-bridge`
