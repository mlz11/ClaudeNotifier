# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeNotifier is a macOS notification app for Claude Code integration. It displays native macOS notifications with Claude's icon, with smart suppression when the user is actively viewing the Claude terminal tab.

## Build Commands

```bash
make build      # Compile, bundle as .app, and codesign to build/ClaudeNotifier.app
make install    # Build + install to /Applications + create CLI at ~/.local/bin/claude-notifier
make uninstall  # Remove app and CLI symlink
make clean      # Remove build directory
```

## Architecture

Single-file Swift application (`Sources/ClaudeNotifier/main.swift`) with no external dependencies.

**Key components:**
- **Notification display** (lines 142-167): Uses `UNUserNotificationCenter` with async semaphore pattern
- **CLI parser** (lines 169-216): Custom argument parsing for `-t`, `-s`, `-m` flags and `setup` subcommand
- **Setup command** (lines 65-138): Auto-configures `~/.claude/settings.json` hooks and installs notify.sh
- **Embedded notify.sh script** (lines 8-61): Smart wrapper that detects iTerm2 focus state via AppleScript to suppress notifications when user is viewing the active tab

**Entry flow:** Parse args → show notification → request permission → add to notification center → wait on semaphore → exit

## CLI Usage

```bash
claude-notifier -m "Message" -t "Title" -s "Subtitle"
claude-notifier setup    # Auto-configure Claude Code hooks
```

## Technical Notes

- Requires macOS 11.0+
- Uses only native frameworks: UserNotifications, Foundation
- Makefile uses `swiftc` directly (not full SPM build) for the app bundle
- App is ad-hoc codesigned during build
