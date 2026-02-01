<p align="center">
  <img src="assets/icon.svg" alt="ClaudeNotifier Icon" width="128" height="128">
</p>

<h1 align="center">ClaudeNotifier</h1>

<p align="center">
  A macOS notification app for Claude Code integration.<br>
  Displays native notifications with Claude's icon and focuses the correct terminal tab when clicked.
</p>

## Features

- Native macOS notifications with Claude's icon
- Smart suppression when you're viewing the active Claude terminal tab
- **Click-to-focus**: Clicking a notification switches to the terminal tab that triggered it
- Includes repo/directory name as subtitle
- Supports iTerm2 and Terminal.app

## Installation

### Homebrew (Recommended)

```bash
brew install mlz11/tap/claude-notifier
```

### From Source

```bash
git clone https://github.com/mlz11/ClaudeNotifier.git
cd ClaudeNotifier
make install
```

This builds the app, installs it to `/Applications/ClaudeNotifier.app`, and creates a `claude-notifier` CLI command in `~/.local/bin`.

If `~/.local/bin` is not in your PATH, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

### Quick Setup for Claude Code

```bash
claude-notifier setup
```

This automatically:
- Installs the notification script to `~/.claude/notify.sh`
- Adds hooks to `~/.claude/settings.json`

### Sending Notifications

```bash
claude-notifier -m "Message" -t "Title" -s "Subtitle"
```

### Options

- `-m "message"` - The notification body (required)
- `-t "title"` - The notification title (default: "Claude")
- `-s "subtitle"` - The notification subtitle (optional)
- `-i "session"` - Session ID for focus-on-click (optional, auto-set by notify.sh)
- `-T "type"` - Terminal type: `iterm2`, `terminal` (optional, auto-detected)

## How It Works

The setup installs a smart notification script that:
- Detects your terminal (iTerm2 or Terminal.app)
- Skips notifications if you're focused on the terminal tab running Claude
- Shows notifications when you're in a different app or different tab
- Includes the current repo/directory name as a subtitle
- Passes session info so clicking focuses the correct tab

## Permissions

During setup, macOS will prompt for permission to control your terminal(s). This is required for the click-to-focus feature.

You can manage this in: **System Settings → Privacy & Security → Automation → ClaudeNotifier**

## Requirements

- macOS 11.0+
- iTerm2 or Terminal.app

## FAQ

<details>
<summary><strong>Why not use Anthropic's recommended terminal notification setup?</strong></summary>

Anthropic provides [official documentation](https://docs.anthropic.com/en/docs/claude-code/terminal-setup#iterm-2-system-notifications) for enabling iTerm2 system notifications. However, this method didn't work reliably for us—notifications simply never appeared on multiple machines, and colleagues experienced the same issue.

ClaudeNotifier was built as a more reliable alternative that also adds extra features like click-to-focus and smart suppression.

</details>

<details>
<summary><strong>Why isn't Warp terminal supported?</strong></summary>

Warp does not support AppleScript and doesn't expose a session ID environment variable. Without these, we cannot:
- Detect which tab triggered the notification
- Focus a specific tab when clicking a notification
- Check if you're viewing the active tab (for smart suppression)

The Warp team prefers URI schemes over AppleScript, but these don't yet support focusing specific tabs.

**Relevant issues:**
- [AppleScript support request](https://github.com/warpdotdev/Warp/issues/3364)
- [Scripting & CLI discussion](https://github.com/warpdotdev/Warp/discussions/612)

</details>

<details>
<summary><strong>Why isn't Ghostty terminal supported?</strong></summary>

Ghostty currently lacks the APIs needed for full integration:
- No `TERM_SESSION_ID` equivalent environment variable ([discussion](https://github.com/ghostty-org/ghostty/discussions/9084))
- AppleScript support is planned but not yet implemented ([discussion](https://github.com/ghostty-org/ghostty/discussions/2353))

Ghostty 1.2.0 added App Intents/Shortcuts support, but this doesn't include focusing specific tabs by ID.

Once Ghostty adds AppleScript support and a session ID environment variable, we can add support.

</details>

## License

MIT
