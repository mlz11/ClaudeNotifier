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

Add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t 'Claude Code' -m 'Awaiting your input'"
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
            "command": "/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier -t 'Claude Code' -m 'Task completed'"
          }
        ]
      }
    ]
  }
}
```

## Requirements

- macOS 11.0+
- Claude.app installed (for the icon)

## License

MIT
