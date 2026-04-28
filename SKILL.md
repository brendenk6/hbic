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

## Click Method Decision Tree

Pick the right click tool the first time:

| Target | Tool | Why |
|--------|------|-----|
| Native macOS apps, Terminal, Finder | `hid click <x> <y>` | IOHIDPostEvent works on native UI |
| Electron / web apps (Codex, ChatGPT, Slack, VS Code, Discord) | `cliclick c:<x>,<y>` | IOHIDPostEvent does NOT register on webview elements |
| macOS system permission dialogs | Accessibility API via `osascript` | Both `hid` and `cliclick` blocked at this layer |
| Menu bar items (any app) | `osascript ... click menu item ...` | Menus are AX-only |
| Browser page content (Chrome / Safari) | **JS execute via AppleScript** — see Apps section | Faster and pixel-independent |

```bash
/opt/homebrew/bin/cliclick c:<x>,<y>          # click
/opt/homebrew/bin/cliclick dc:<x>,<y>         # double-click
/opt/homebrew/bin/cliclick rc:<x>,<y>         # right-click
/opt/homebrew/bin/cliclick kp:return          # press Enter
/opt/homebrew/bin/cliclick t:'text'           # type ASCII (no newlines, no special chars)
```

For complex text (em dashes, newlines, multi-line, non-ASCII): `pbcopy` then `cmd+v` paste — see System Primitives.

## Terminal (AppleScript — runs direct, not through HTTP service)

**Discovery / focus / control commands** — these are safe to use freely:

```bash
hid term                       # list all terminal windows + tabs + TTYs + processes
hid term claude                # find claude code sessions (window ID + TTY + name)
hid term new                   # open new terminal window
hid term focus <window_id>     # bring window to front
hid term compact <window_id>   # focus + type /compact + enter (purpose-built trigger)
```

**Do NOT use `hid term type` for messaging.** It exists in the `hid` CLI but it's unreliable for any real prompt — `hid key cmd+v` can degrade into a literal `v`, and `hid term type` can fail to submit the line. **For ALL terminal messaging — short, long, ASCII, Unicode, single-line, multi-line — use the AppleScript clipboard pattern below.** No exceptions for "tiny ASCII pokes," no fallbacks to `hid term type`. AppleScript is the default and only path.

### Terminal messaging — the ONE pattern (always use this)

**Run a command in a new Terminal window:**
```bash
osascript <<'APPLESCRIPT'
tell application id "com.apple.Terminal"
  activate
  do script "cd /path/to/project && your-command-here"
end tell
APPLESCRIPT
```

**Send any prompt (short or long) to an existing Terminal window:**
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

This works for every messaging case: orchestrating other LLMs (Codex, Kimi, Gemini, Claude), sending one-line pings, multi-paragraph briefs, prompts with em-dashes / Unicode / newlines / quoted code blocks. There is no situation where `hid term type` is preferable.

The only legitimate `hid term *` typing command is `hid term compact <wid>` — it's a purpose-built `/compact` trigger that handles the focus + keystroke + return sequence and is shaped for Claude Code's idle-window timing. Don't reach for `hid term type` to roll your own version of that or anything else.

## Apps via AppleScript

macOS apps with scripting dictionaries can be driven directly — no clicking, no screenshots. Two flavors:

1. **Native AppleScript-aware apps** — full data API (Mail, Calendar, Notes, Reminders, Messages, Music, Pages, Keynote, Numbers, TextEdit, Finder)
2. **Browsers** — limited dictionary + JS-execute escape hatch (Chrome, Safari)

### Browser control (Chrome / Safari)

List all tabs across all windows:
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

Active tab read / navigate:
```bash
osascript -e 'tell application "Google Chrome" to URL of active tab of front window'
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://..."'
open -a "Google Chrome" "https://..."          # opens in new tab if app running
```

**Execute JS in any tab** (the killer feature — read DOM, fill forms, scrape):
```bash
osascript -e 'tell application "Google Chrome" to execute active tab of front window javascript "document.title"'
osascript -e 'tell application "Google Chrome" to execute tab 3 of front window javascript "JSON.stringify({h1: document.querySelector(\"h1\").innerText})"'
```

**One-time gotcha**: JS execution is OFF by default in Chrome. Toggle ON (per Chrome session, not persistent across relaunch):
```bash
osascript -e 'tell application "Google Chrome" to activate' \
          -e 'tell application "System Events" to tell process "Google Chrome" to click menu item "Allow JavaScript from Apple Events" of menu 1 of menu item "Developer" of menu 1 of menu bar item "View" of menu bar 1'
```
Verify (returns "✓" if on, "missing value" if off):
```bash
osascript -e 'tell application "System Events" to tell process "Google Chrome" to value of attribute "AXMenuItemMarkChar" of menu item "Allow JavaScript from Apple Events" of menu 1 of menu item "Developer" of menu 1 of menu bar item "View" of menu bar 1'
```

**Safari** — same idea, different command and menu path. Develop menu must be enabled first (Safari → Settings → Advanced → Show features for web developers):
```bash
osascript -e 'tell application "Safari" to do JavaScript "document.title" in current tab of front window'
```

JS results return as strings — wrap complex data in `JSON.stringify(...)` and parse on the shell side. Tabs are 1-indexed.

### Native AppleScript-aware apps

Drive these as data, not pixels. Open Script Editor → File → Open Dictionary → pick app for the full API.

```bash
# Notes — create
osascript -e 'tell application "Notes" to make new note at folder "Notes" with properties {name:"Title", body:"<b>Body HTML</b>"}'

# Reminders — add with due date
osascript -e 'tell application "Reminders" to make new reminder with properties {name:"Pick up groceries", due date:date "Saturday, April 25, 2026 5:00 PM"}'

# Calendar — event
osascript -e 'tell application "Calendar" to tell calendar "Home" to make new event with properties {summary:"Meeting", start date:(current date), end date:(current date) + 1 * hours}'

# Messages — send iMessage
osascript -e 'tell application "Messages" to send "Hi" to buddy "+15551234567" of (service 1 whose service type is iMessage)'

# Mail — compose
osascript -e 'tell application "Mail" to make new outgoing message with properties {subject:"...", content:"...", visible:true}'

# Finder — reveal a path
osascript -e 'tell application "Finder" to reveal POSIX file "/path/to/file"'
open -R /path/to/file                          # shorter equivalent
```

### Accessibility tree (works on any app)

Faster than screenshot+OCR for finding labeled elements. Works on apps without scripting dictionaries.

```bash
# Dump entire UI hierarchy of front window
osascript -e 'tell application "System Events" to tell process "App Name" to entire contents of window 1'

# Click a button by label
osascript -e 'tell application "System Events" to tell process "App Name" to click (first button whose name is "Submit") of window 1'

# Read a text field's value
osascript -e 'tell application "System Events" to tell process "App Name" to value of text field 1 of window 1'

# Set a text field's value (bypasses typing)
osascript -e 'tell application "System Events" to tell process "App Name" to set value of text field 1 of window 1 to "hello"'

# List all windows of an app
osascript -e 'tell application "System Events" to tell process "App Name" to name of every window'
```

When AX paths get long: dump `entire contents` first, locate target, then write the precise path.

### Notifications back to the user

Ping the user when long tasks finish — only way to interrupt politely:

```bash
osascript -e 'display notification "Build done" with title "Claude" sound name "Glass"'
osascript -e 'display notification "Tests failed: 3" with title "Claude" subtitle "Math 148" sound name "Basso"'
```
Sounds: `Glass`, `Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`.

For modal that blocks until dismissed:
```bash
osascript -e 'display dialog "Need confirmation?" buttons {"No", "Yes"} default button "Yes"'
# returns: button returned:Yes
```

## System Primitives

### `open` — launch apps and URLs
```bash
open -a "Google Chrome" "https://example.com"  # open URL in specific app
open -a Specter                                # launch app
open /path/to/file.pdf                         # open with default app
open -R /path/to/file                          # reveal in Finder
open -e file.txt                               # open in TextEdit
```

### Clipboard
```bash
pbcopy < file.txt                              # copy file contents
echo "text" | pbcopy                           # copy string
pbpaste                                        # print clipboard
pbpaste > out.txt                              # save clipboard to file
```

For typing long or complex text into any app — fastest, most reliable path:
```bash
echo "complex text with em—dashes and newlines" | pbcopy
hid click <x> <y>          # focus the field
hid key cmd+v              # paste
```
Beats `hid type` for anything over a paragraph or with special characters.

### Process management
```bash
pgrep -l "Google Chrome"                       # is it running? (returns PID + name)
pgrep -lf "specific command line"              # match full argv
pkill -f "App Name"                            # kill all matching
killall "App Name"                             # kill by app name
```

### Volume / display / sleep
```bash
osascript -e 'set volume output volume 50'     # 0-100
osascript -e 'set volume with output muted'    # mute
osascript -e 'set volume without output muted' # unmute
pmset displaysleepnow                          # sleep display only
caffeinate -d -t 3600                          # prevent display sleep for 1hr
```

### Window position and size (any app)
```bash
osascript -e 'tell application "System Events" to tell process "App Name" to set position of window 1 to {0, 0}'
osascript -e 'tell application "System Events" to tell process "App Name" to set size of window 1 to {1200, 800}'
# Both at once:
osascript -e 'tell application "System Events" to tell process "Safari" to set {position, size} of window 1 to {{0, 0}, {1200, 800}}'
```

## HTTP API (for programmatic use)

All endpoints need `Authorization: Bearer <token>` header.

```
# Mouse
GET  /mouse/position
POST /mouse/move          {"x": 100, "y": 200}
POST /mouse/click         {"x": 100, "y": 200}
POST /mouse/doubleclick   {"x": 100, "y": 200}
POST /mouse/rightclick    {"x": 100, "y": 200}
POST /mouse/drag          {"from_x": 0, "from_y": 0, "to_x": 100, "to_y": 100}
POST /mouse/scroll        {"dy": -3, "dx": 0}

# Keyboard
POST /keyboard/type       {"text": "hello"}
POST /keyboard/press      {"keys": "cmd+c"}
POST /keyboard/down       {"keys": "shift"}
POST /keyboard/up         {"keys": "shift"}

# Screen
GET  /screen/size
GET  /screen/capture
POST /screen/capture/region  {"x": 0, "y": 0, "width": 500, "height": 500}

# Windows
GET  /windows
POST /windows/search      {"app": "Terminal"}
POST /windows/capture     {"window_id": 1234}

# Terminal
GET  /terminal/claude
POST /terminal/compact    {"window_id": 1234}
```

## Patterns

### Click a specific app element
1. `hid windows find <App>` to get window position
2. `hid capture` to see what's on screen
3. Calculate coordinates from screenshot + window bounds
4. `hid click <x> <y>`

### Type into an app
1. Click the input field first: `hid click <x> <y>`
2. Then type: `hid type "text here"`
3. For special keys: `hid key return` or `hid key cmd+a`

### Compact another claude session
1. `hid term claude` to list sessions with window IDs
2. `hid term compact <window_id>`

### Self-compact (compact YOUR OWN session)
1. `hid term claude` to find your own window ID (match by TTY or process)
2. `hid term compact <your_window_id>` — types `/compact` + Enter into your own terminal
3. The `/compact` lands during the idle gap after your current response finishes
4. Context compresses automatically (e.g. 320K → 46K tokens)
**Timing is critical**: `/compact` only works when Claude Code is idle at the input prompt. If it lands mid-response, it gets swallowed. Always send it as the LAST action before your response ends.

### Open a new terminal and run something
Always use AppleScript `do script` so Terminal itself inserts the command. There is no fallback — `hid term new` + `hid term type` is unreliable for any real command and should not be used.
```bash
osascript <<'APPLESCRIPT'
tell application id "com.apple.Terminal"
  activate
  do script "cd /path/to/project && your command here"
end tell
APPLESCRIPT
```

### Take a screenshot and read it
```bash
hid capture /tmp/screen.png
# Then use Read tool on /tmp/screen.png to see it
```

### Driving multi-step web forms

For homework platforms, grant portals, multi-tab signups — anything with a "Submit" or "Check" button that's one-shot or rate-limited — three rules survive across sites:

1. **Verify before one-shot actions.** Many platforms cap "Check answer" or "Submit" to a single attempt. Read the form back via JS BEFORE clicking — confirm every field is filled, totals balance, and any "to account for" reconciliation matches. The button doesn't warn about empty fields.

2. **Multi-tab forms: fill EVERY tab before submitting.** A single Submit usually covers all tabs at once. Filling the visible tab and clicking submit wastes your one shot on a partial answer.

3. **Read dropdown options before filling.** Don't guess label text — exact spelling and special characters (em-dashes, fractions) matter. Most spreadsheet/form widgets expose the option list via the contentWindow's data layer (e.g. jSheet stores them at `workBook.dropDownReference[N].list`). Look for it before typing.

Common navigation gotchas:

- **Resume splash.** Re-entering a partially-completed form often goes through a summary page first ("Continue"/"Resume"/"Begin"). Don't assume the assignment link drops you on the question.
- **Next-button skip.** Some platforms' "Next" advances 2 items if you click during a save. Always verify location after navigation, not just after page load.
- **Duplicate-tab errors.** Clicking an LMS link while a prior session is still loading can spawn a duplicate tab and trigger "You already have this assignment open." Recovery: close the duplicate, re-enter through the original path.

Driving the form: same DOM patterns over different transports. Chrome/Safari JS-execute (above) works on any user's machine. On Brenden's Mac, prefer Specter (localhost:7777) — site-specific patterns live in the `specter-web-interaction` skill.

### Cross-LLM Communication Checklist (DO THIS EVERY TIME)

Before sending ANY task to another LLM, complete these steps in order:
1. **Identify yourself** — name, model, your terminal window ID
2. **Establish chain of command** — the user is the boss, you are coordinating
3. **Tell them to load HBIC** — `cat ~/.claude/skills/hbic/SKILL.md` (so they know to reply via the AppleScript clipboard pattern, not `hid term type`)
4. **Give them your window ID** — they will reply via the AppleScript clipboard pattern aimed at your window
5. **THEN send the task** — not before steps 1-4

Skipping the intro means the other LLM doesn't know who's talking, who has authority, or how to respond. Do not skip this.

### Chat with another LLM in a terminal
1. Start the other LLM with Terminal AppleScript:
   ```bash
   osascript <<'APPLESCRIPT'
   tell application id "com.apple.Terminal"
     activate
     do script "kimi" -- or gemini/codex/claude
   end tell
   APPLESCRIPT
   ```
2. Wait a few seconds for it to boot, then run `hid term` to get its window ID.
3. **Find your own terminal window ID first:** `hid term claude` to get your window ID.
4. **Introduce yourself first.** Tell them who you are, your window ID, and the chain of command. Use the AppleScript clipboard pattern from "Terminal messaging — the ONE pattern" to paste and submit the intro:
   `I'm Claude (Opus 4.6), orchestrating from terminal window <YOUR_WID> on the user's Mac. The user has final authority. I'm going to give you a task to work on. When you're done or need help, message me back using the AppleScript clipboard pattern from ~/.claude/skills/hbic/SKILL.md aimed at window <YOUR_WID> — pbcopy your message then osascript keystroke cmd-v + return. Do NOT use 'hid term type' — it's unreliable. The HBIC skill at ~/.claude/skills/hbic/SKILL.md has the full pattern and all available commands.`
5. Then send the actual task with the same AppleScript clipboard pattern.
6. Read replies via AppleScript:
```bash
osascript -e 'tell application "Terminal" to return history of tab 1 of window id <wid>' | tail -30
```
7. After sending a message, wait before reading — give the LLM time to respond.

### Monitoring another LLM's work
**Check frequently at first** (every 10-20 seconds) to make sure the LLM:
- Understood the task correctly
- Has the right permissions (approve shell access for session)
- Isn't going down the wrong path

**Then space out to 1-5 minutes** once they're on track. Read their terminal history to check progress.

**Guide them if needed:**
- If stuck on a bug, inspect the problem yourself and send hints with context
- If going the wrong direction, redirect clearly: "Stop working on X, focus on Y instead"
- If they're burning context on polish, tell them to ship what they have
- Use the System Events ctrl-s pattern to inject messages immediately when urgent

**Tell them to load HBIC:** Ask the other LLM to read `~/.claude/skills/hbic/SKILL.md` so they know to message you back via the AppleScript clipboard pattern (NOT `hid term type`), and how to find your terminal window via `hid term claude`.

### Chat with another Claude in a terminal
When the other LLM is also a Claude Code instance:

1. **Submit via AppleScript, not HID** — `hid term type` does NOT auto-submit, `hid key <wid> return` is unreliable, and `hid key cmd+v` can type a literal `v`. The reliable pattern is:
   ```bash
   pbcopy <<'PROMPT'
   your message
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
2. **Force Claude to read your message** — If the other Claude is mid-generation, press `Ctrl+B` to interrupt and force it to process your queued input.
3. **Cancel/Stop Claude** — Press `Esc` twice to cancel Claude's current generation.

### Parallel Work Coordination (NO OVERLAPS)
When multiple Claude instances (or any LLMs) work on the same project:
1. **Agree on file ownership BEFORE starting** — each agent claims specific files. No two agents edit the same file.
2. **Wait for the other agent's response before coding** — don't start work until you've confirmed the split. Starting early risks duplicate or conflicting changes.
3. **State your claimed files explicitly** in the coordination message so the other agent can confirm or counter-propose.
4. **If you need to touch a file the other agent owns**, message them first and wait for acknowledgment.
5. **Report what you changed** after finishing a task so the other agent knows the current state.

### Interrupt an LLM that's generating (inject message immediately)
LLM CLIs queue typed messages while generating. To force-send immediately:
```bash
# hid key ctrl+s does NOT work — IOHIDPostEvent ctrl+s doesn't register with terminal CLI apps
# Use System Events AppleScript instead:
osascript -e 'tell application "Terminal" to set frontmost of window id <wid> to true' -e 'tell application "System Events" to keystroke "s" using control down'
```
This sends a real ctrl-s that Kimi/Claude/etc. recognize as "send immediately." Use this when messages show as "queued" while the LLM is mid-response.

### Start an LLM CLI
Available LLM CLIs: `kimi`, `gemini`, `codex`, `claude`
Or use `~/bin/llms <name>` to launch in a new Terminal window directly.

### LLM Memory Files (persistent instructions each CLI loads on startup)
| CLI | File | Notes |
|-----|------|-------|
| Claude | `~/.claude/CLAUDE.md` | Source of truth. Identity + orchestration note |
| Kimi | `~/KIMI.md` | Kimi's own memory (between markers) + synced Claude context |
| Gemini | `~/.gemini/GEMINI.md` | Auto-synced from Claude |
| Codex | `~/.codex/AGENTS.md` | Auto-synced from Claude |

**Sync script**: `~/.claude/projects/<your-project-id>/memory/scripts/sync_external_clis.py` runs after `scripts/index.py` regenerates MEMORY.md. Propagates CLAUDE.md + memory index into all CLI files. (Project IDs are URL-encoded versions of your project's working directory — e.g. `-Users-yourname-someproject`.)

**Kimi special handling**: `~/KIMI.md` has two sections. Kimi's own persistent memory lives between `<!-- KIMI_OWN_MEMORY_START -->` and `<!-- KIMI_OWN_MEMORY_END -->` markers. The sync script preserves this section and appends the Claude context after it.

### Dismissing macOS permission dialogs
macOS system permission dialogs (Screen Recording, Accessibility, etc.) block IOHIDPostEvent and cliclick. Use the Accessibility API through UserNotificationCenter:
```bash
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Allow" of window 1'
```
To inspect dialog contents first:
```bash
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to return entire contents of window 1'
```

### Codex (OpenAI) desktop app + CLI

**Architecture** — App is Electron wrapping the Rust binary at `/Applications/Codex.app/Contents/Resources/codex` (bundle id `com.openai.codex`). Live process spawns `codex app-server --analytics-default-enabled` for backend. App + CLI share `~/.codex/` (config.toml, sessions/, threads/, memories/, skills/, plugins/, AGENTS.md).

**Two codex binaries on this Mac** — match the surface to the install:
- `/Applications/Codex.app/Contents/Resources/codex` — Rust, current with app (e.g. `26.422.30944`). Use this for IPC into the running app.
- `~/.npm-global/bin/codex` (on PATH, if installed via `npm install -g @openai/codex`) — `codex-cli` Node wrapper. Older than the bundled binary. Update via `npm install -g @openai/codex@latest`.

**Drive the running app via IPC** — preferred over mouse/keyboard for the desktop app:
```bash
/Applications/Codex.app/Contents/Resources/codex app-server proxy
# stdio ↔ live app-server control socket. Use bundled binary for protocol match.

/Applications/Codex.app/Contents/Resources/codex app-server generate-json-schema
# inspect the protocol
```

**CLI subcommands** (`codex --help` for full list):
| Command | Use |
|---------|-----|
| `codex exec "..."` | Non-interactive one-shot (scriptable) |
| `codex resume --last` | Pick up most recent session |
| `codex fork --last` | Fork most recent session |
| `codex apply` | `git apply` the last diff |
| `codex review` | Non-interactive code review |
| `codex cloud` | Browse Codex Cloud tasks, apply locally |
| `codex mcp-server` | Run Codex itself as an MCP server (stdio) |
| `codex sandbox` | Run a command inside Codex's sandbox |

**Common flags**: `-c model=gpt-5.5`, `-c model_reasoning_effort=xhigh`, `-m gpt-5.5`, `--full-auto`, `-s {read-only,workspace-write,danger-full-access}`, `--search`, `-i image.png`, `-C dir`, `-a {untrusted,on-request,never}`, `--dangerously-bypass-approvals-and-sandbox`.

**App concepts**:
- Modes per thread: **Local / Worktree / Cloud**. Cloud is a separate usage bucket from local — under the 10x Pro promo (through May 31, 2026), milk both by firing cloud jobs from the app while iterating locally.
- Trusted dirs gate auto-approval — see `[projects."/path"]` blocks in `~/.codex/config.toml`.
- Bundled MCP servers run automatically: `SkyComputerUseClient mcp` (computer use), `browser-use`. Already in process list when app is running.
- `$imagegen` in a prompt triggers gpt-image-2 (counts ~3-5x toward usage limits).
- Shortcuts: `Cmd+J` integrated terminal, `Cmd+K` command palette, `Ctrl+M` voice dictation, `Ctrl+L` clear terminal (NOT Cmd+K — that's the palette).

**1M context toggle is GONE in GPT-5.5** — `model_context_window = 1000000` in config.toml is a no-op on 5.5 (GitHub issue `openai/codex#19208` closed as not-planned). Stay on `gpt-5.4` if you need the 1M window.

**Screen-control fallback** (when IPC can't reach a UI element) — Codex is Electron, IOHIDPostEvent clicks DO NOT register. Use `cliclick`:
- Model picker: model pill at bottom of input (e.g. "GPT-5.5 v") opens dropdown with Intelligence levels + "GPT-X.X >" submenu. Click model name to expand, then click target version.
- Update button: blue pill in top-left near traffic lights, only visible when update available.
- Send: paste with `cmd+v` then `cliclick c:<x>,<y>` on the send button (circle with up arrow) bottom-right of input bar.
- Tooltip shortcuts can conflict with macOS (e.g. picker shows `Shift+Cmd+M` but `Cmd+M` minimizes) — always cliclick the element.

### Getting pixel coordinates with Prism vision encoder
Use `encode_screenshot()` with max settings for OCR + UI element detection:
```python
from prism.ascii_vision import encode_screenshot, _ocr_vision_framework
# Full analysis (OCR + UI elements + braille grid)
text, spatial, ui_elements, ocr_texts = encode_screenshot('/tmp/screenshot.png', ocr=True, fullmap=True)
# Quick OCR only (returns TextRegion list with pixel bboxes)
regions = _ocr_vision_framework('/tmp/screenshot.png')
```
Coordinates are in Retina 2x pixels. Convert to screen: `screen_x = img_x // 2`, `screen_y = img_y // 2`. For window captures (`hid wcapture`), add window origin: `screen_x = window_x + img_x // 2`, `screen_y = window_y + img_y // 2`.

### Coordinate workflow for clicking UI elements
1. Take screenshot: `hid capture /tmp/screen.png` (full) or `hid wcapture <wid> /tmp/win.png` (window)
2. Run OCR: `_ocr_vision_framework('/tmp/screen.png')` to get TextRegion list with pixel bboxes
3. Find target text, compute center: `cx = (bbox[0]+bbox[2])//2`, `cy = (bbox[1]+bbox[3])//2`
4. Convert to screen coords: divide by 2 (Retina), add window origin if using wcapture
5. Click with appropriate method: `cliclick c:<x>,<y>` for Electron, `hid click <x> <y>` for native

## Key Details

- Mouse uses `CGWarpMouseCursorPosition` (absolute, no permission needed)
- Clicks/keys use `IOHIDPostEvent` (kernel HID path, no Accessibility needed for mouse)
- Keyboard typing via IOHIDPostEvent — Accessibility permission GRANTED (2026-04-22), Screen Recording also enabled
- **IOHIDPostEvent clicks do NOT work on Electron webview elements** — use `/opt/homebrew/bin/cliclick` instead
- Screenshots use `CGDisplayCreateImage` (direct framebuffer, no disk I/O)
- Screenshots do NOT capture the Dock (Liquid Glass overlay layer)
- Window capture falls back to region crop if per-window capture lacks Screen Recording permission
- Terminal commands (`hid term *`) use AppleScript directly from shell, NOT through the HTTP service (launchd lacks Automation permission for Terminal.app)
- Service runs as launchd agent: `com.brenden.claude-desktop-bridge`
