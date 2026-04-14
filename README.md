# cc-notify

Native macOS notifications for [Claude Code](https://claude.ai/code) — with sound, click-to-open, session context, and duration tracking.

Zero dependencies. Pure Swift. Works on macOS 14+.

---

## What it does

When Claude Code needs your attention, you get a notification like this:

```
┌─────────────────────────────────────┐
│ [icon]  my-project · Permission     │
│         feature-branch              │
│         Run: npm run build          │
└─────────────────────────────────────┘
```

- **Title** — project folder + what's happening (`Permission`, `Input Needed`, `Done`)
- **Subtitle** — session name (shown only when you've renamed the session)
- **Body** — the specific action or message from Claude
- **Sound** — default macOS notification sound
- **Click** — opens the terminal or editor that triggered the notification

When a task finishes, you get the duration:
```
my-project · Done
Finished in 2m 34s
```

---

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code](https://claude.ai/code) installed and configured
- Xcode Command Line Tools: `xcode-select --install`

---

## Installation

```bash
git clone https://github.com/your-username/cc-notify.git
cd cc-notify
make install
```

That's it. The installer will:

1. Compile the Swift source
2. Bundle and sign the app (`~/Applications/CCNotify.app`)
3. Register it with macOS so it can send notifications
4. Add three hooks to your `~/.claude/settings.json`
5. Send a test notification to confirm everything works

> **First notification?** macOS will ask permission the first time. Click Allow.

---

## Uninstall

```bash
make uninstall
```

Removes the app and cleans up the Claude Code hooks. Your other settings.json configuration is untouched.

---

## Supported terminals (click-to-open)

Clicking a notification brings the originating terminal or editor to the front:

| Terminal / Editor | Detection |
|---|---|
| [Warp](https://www.warp.dev) | `$TERM_PROGRAM=WarpTerminal` |
| [VS Code](https://code.visualstudio.com) | `$TERM_PROGRAM=vscode` |
| [Cursor](https://cursor.com) | `$TERM_PROGRAM=cursor` |
| [Ghostty](https://ghostty.org) | `$TERM_PROGRAM=ghostty` |
| [iTerm2](https://iterm2.com) | `$TERM_PROGRAM=iTerm.app` |
| Apple Terminal | `$TERM_PROGRAM=Apple_Terminal` |

---

## Notification types

cc-notify maps Claude Code hook events to contextual notification content:

| Hook event | Notification type | Title | Body |
|---|---|---|---|
| `Notification` | `permission_prompt` | `folder · Permission` | Tool or command Claude wants to run |
| `Notification` | `idle_prompt` | `folder · Input Needed` | Claude's question |
| `Notification` | `elicitation_dialog` | `folder · Question` | Claude's question |
| `Notification` | `auth_success` | `folder · Authorized` | Permission granted |
| `Stop` | — | `folder · Done` | "Finished in Xm Ys" |

---

## How it works

Claude Code supports [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell commands that run on specific events. cc-notify installs three hooks:

```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "..."}]}],
    "Notification":     [{"hooks": [{"type": "command", "command": "..."}]}],
    "Stop":             [{"hooks": [{"type": "command", "command": "..."}]}]
  }
}
```

Each hook pipes the event JSON to a temp file, then launches `CCNotify.app` with the event name and file path as arguments.

**Duration tracking** — `UserPromptSubmit` saves a timestamp. When `Stop` fires, it reads the timestamp and reports elapsed time.

**Icon display** — macOS 26 doesn't show bundle icons for ad-hoc signed apps in Notification Center. cc-notify works around this using `UNNotificationAttachment`, which embeds the icon as a notification image.

**Background app** — CCNotify runs as `LSUIElement`, so it never appears in the Dock or App Switcher.

---

## Development

```bash
# Build only (no install)
make build

# Run all test notifications
make test

# Clean build artifacts
make clean
```

### Project structure

```
cc-notify/
├── Sources/CCNotify/
│   ├── main.swift                # Entry point, AppDelegate
│   ├── NotificationBuilder.swift # Notification content + delivery
│   ├── SessionResolver.swift     # Session name and project folder lookup
│   ├── DurationTracker.swift     # Timestamp tracking for duration display
│   └── TerminalResolver.swift    # TERM_PROGRAM → bundle ID mapping
├── Resources/
│   ├── icon.svg                  # Source icon (Claude Code chip on dark bg)
│   └── icon.png                  # Pre-rendered 512×512 PNG
├── Support/
│   └── Info.plist                # App bundle metadata
├── Scripts/
│   ├── install.sh                # Hook configuration (non-destructive)
│   └── uninstall.sh              # Hook removal
├── Tests/
│   └── test-notifications.sh    # Manual notification tests
└── Makefile
```

### Adding terminal support

Edit `Sources/CCNotify/TerminalResolver.swift` and add your terminal's `TERM_PROGRAM` value and bundle identifier to the `map` dictionary:

```swift
"MyTerminal": "com.example.MyTerminal",
```

PRs for additional terminals are welcome. Please connact me for any collaboration 

---

## License

MIT — see [LICENSE](LICENSE).
