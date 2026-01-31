# ClaudeNotifier

A macOS notification app for Claude Code integration. Displays native notifications with Claude's icon and focuses the correct iTerm2 tab when clicked.

## Features

- Native macOS notifications with Claude's icon
- Smart suppression when you're viewing the active Claude terminal tab
- **Click-to-focus**: Clicking a notification switches to the iTerm2 tab that triggered it
- Includes repo/directory name as subtitle

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
- `-i "session"` - iTerm2 session ID for focus-on-click (optional, auto-set by notify.sh)

## How It Works

The setup installs a smart notification script that:
- Skips notifications if you're focused on the iTerm2 tab running Claude
- Shows notifications when you're in a different app or different iTerm2 tab
- Includes the current repo/directory name as a subtitle
- Passes the iTerm2 session ID so clicking focuses the correct tab

## Permissions

On first notification click, macOS will prompt for permission to control iTerm2. This is required for the click-to-focus feature to work.

You can manage this in: **System Settings → Privacy & Security → Automation → ClaudeNotifier**

## Requirements

- macOS 11.0+
- iTerm2 (for click-to-focus feature)

## License

MIT
