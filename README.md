# ClaudeNotifier

A simple macOS notification app that displays notifications with Claude's icon. Useful for integrating with Claude Code hooks or other scripts.

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

## How It Works

The setup installs a smart notification script that:
- Skips notifications if you're focused on the iTerm2 tab running Claude
- Shows notifications when you're in a different app or different iTerm2 tab
- Includes the current repo/directory name as a subtitle

## Requirements

- macOS 11.0+

## License

MIT
