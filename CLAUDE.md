# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeNotifier is a macOS notification app for Claude Code integration. It displays native macOS notifications with Claude's icon, with smart suppression when the user is actively viewing the Claude terminal tab. Clicking a notification focuses the iTerm2 tab that triggered it.

## Build Commands

```bash
make build      # Compile, bundle as .app, and codesign to build/ClaudeNotifier.app
make install    # Build + install to /Applications + create CLI at ~/.local/bin/claude-notifier
make uninstall  # Remove app and CLI symlink
make clean      # Remove build directory
make lint       # Run SwiftLint
make format     # Run SwiftFormat
make setup      # Install pre-commit hooks
```

## Pre-commit Hooks

Run `make setup` after cloning to install git hooks. On each commit:
- **SwiftFormat** auto-formats staged Swift files
- **SwiftLint** checks for violations (strict mode)
- **Conventional commits** validates commit message format

Commit messages must follow [Conventional Commits](https://conventionalcommits.org):
```
feat: add new feature
fix: resolve bug
docs: update readme
chore: update dependencies
```

## Architecture

Single-file Swift application (`Sources/ClaudeNotifier/main.swift`) using AppKit and UserNotifications frameworks.

**Key components:**
- **NotificationConfig/ParsedArguments** (lines 6-19): Data structures for notification and CLI argument handling
- **Embedded notify.sh script** (lines 23-62): Smart wrapper that detects iTerm2 focus state via AppleScript to suppress notifications when user is viewing the active tab
- **Setup command** (lines 65-156): Auto-configures `~/.claude/settings.json` hooks and installs notify.sh
- **focusITermSession** (lines 160-188): Uses AppleScript to focus the iTerm2 tab matching a session ID
- **AppDelegate** (lines 192-275): NSApplicationDelegate and UNUserNotificationCenterDelegate for notification display and click handling
- **CLI parser** (lines 279-324): Custom argument parsing for `-t`, `-s`, `-m`, `-i` flags and `setup` subcommand

**Entry flow:** Parse args → configure NSApplication → show notification (if -m provided) → handle notification click → focus iTerm2 tab → exit

## CLI Usage

```bash
claude-notifier -m "Message" -t "Title" -s "Subtitle"
claude-notifier -m "Message" -i "$ITERM_SESSION_ID"  # With session ID for focus-on-click
claude-notifier setup    # Auto-configure Claude Code hooks
```

## Technical Notes

- Requires macOS 11.0+
- Uses native frameworks: AppKit, UserNotifications
- Makefile uses `swiftc` directly (not full SPM build) for the app bundle
- App is ad-hoc codesigned during build
- Runs as LSUIElement (no dock icon)
- Requires Automation permission for iTerm2 (prompted on first notification click)
