<p align="center">
  <img src="assets/icon.svg" alt="ClaudeNotifier Icon" width="128" height="128">
</p>

<h1 align="center">ClaudeNotifier</h1>

<p align="center">
  A macOS notification app for Claude Code integration.<br>
  Displays native notifications with Claude's icon and focuses the correct terminal tab when clicked.
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/dd8e3cb0-a369-4ff8-baa4-5dbc3e3dff7a" alt="ClaudeNotifier Demo" width="600">
</p>

<p align="center">
  <a href="#why-claudenotifier">Why?</a> •
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#faq">FAQ</a>
</p>

## Why ClaudeNotifier?

Anthropic's [recommended terminal notification setup](https://code.claude.com/docs/en/terminal-config#iterm-2-system-notifications) doesn't work reliably—notifications often never appear. ClaudeNotifier provides a more reliable alternative with extra features like click-to-focus and smart suppression.

## ✨ Features

- Native macOS notifications
- **Click-to-focus**: Clicking a notification switches to the terminal tab that triggered it
- Includes repo/directory name as subtitle
- Supports [iTerm2](https://iterm2.com/) and [Terminal.app](https://support.apple.com/guide/terminal/welcome/mac)

## 📦 Installation

<details open>
<summary><strong>Homebrew (Recommended)</strong></summary>

```bash
brew install mlz11/tap/claude-notifier
```

</details>

<details>
<summary><strong>From Source</strong></summary>

```bash
git clone https://github.com/mlz11/ClaudeNotifier.git
cd ClaudeNotifier
make install
```

You'll be prompted for the install directory (press Enter for default `/Applications`).

This builds the app, installs it to the chosen directory, and creates a `claude-notifier` CLI command in `~/.local/bin`.

If `~/.local/bin` is not in your PATH, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

</details>

## 🚀 Usage

### Quick Setup for Claude Code

```bash
claude-notifier setup
```

You'll be prompted for the Claude config directory (press Enter for default `~/.claude`).

This automatically:
- Installs the notification script to your config directory
- Adds hooks to `settings.json`

### Diagnosing Issues

```bash
claude-notifier doctor
```

This checks your installation and permissions, showing any issues and how to fix them.

### Sending Notifications

```bash
claude-notifier -m "Message" -t "Title" -s "Subtitle"
```

### Options

- `-m "message"` - The notification body (required)
- `-t "title"` - The notification title (default: "Claude")
- `-s "subtitle"` - The notification subtitle (optional)
- `-S "sound"` - Notification sound: `default`, `none`, or a sound name (optional)
  - Examples: `Glass`, `Basso`, `Blow`, `Ping`, `Pop`, `Funk`, `Submarine`
- `-i "session"` - Session ID for focus-on-click (optional, auto-set by notify.sh)
- `-T "type"` - Terminal type: `iterm2`, `terminal` (optional, auto-detected)

## Permissions

ClaudeNotifier requires two macOS permissions, both prompted during `claude-notifier setup`:

1. **Notifications** — Required to display notifications.
   - Manage in: **System Settings → Notifications → ClaudeNotifier**

2. **Automation** — Required for click-to-focus.
   - Manage in: **System Settings → Privacy & Security → Automation → ClaudeNotifier**

## Requirements

- macOS 11.0+
- iTerm2 or Terminal.app

## ❓ FAQ

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
