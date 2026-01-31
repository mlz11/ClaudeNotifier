# ClaudeNotifier

A simple macOS notification app that displays notifications with Claude's icon. Useful for integrating with Claude Code hooks or other scripts.

## Installation

### Quick Install

```bash
make install
```

This builds the app and installs it to `/Applications/ClaudeNotifier.app`.

### Manual Build

```bash
make build
```

The app bundle will be created at `build/ClaudeNotifier.app`.

## Usage

```bash
/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -m "Message" -t "Title" -s "Subtitle"
```

### Options

- `-m "message"` - The notification body (required)
- `-t "title"` - The notification title (default: "Claude")
- `-s "subtitle"` - The notification subtitle (optional)

## Claude Code Integration

For smart notifications that only appear when you're not looking at the Claude tab, use the included wrapper script. Copy `examples/notify.sh` to `~/.claude/notify.sh`:

```bash
cp examples/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

Then add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/notify.sh input_needed"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/notify.sh task_complete"
          }
        ]
      }
    ]
  }
}
```

The wrapper script will:
- Skip notifications if you're focused on the iTerm2 tab running Claude
- Show notifications when you're in a different app or different iTerm2 tab
- Include the current repo/directory name as a subtitle

## Requirements

- macOS 11.0+
- Claude.app installed (for the icon)

## License

MIT
