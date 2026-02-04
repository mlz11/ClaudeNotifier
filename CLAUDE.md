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

Multi-file Swift application using AppKit and UserNotifications frameworks.

**File structure:**
```
Sources/ClaudeNotifier/
├── main.swift           # Entry point - parses args, configures and runs NSApplication
├── Constants.swift      # Shared constants (paths, keys, defaults)
├── Models.swift         # Data structures (NotificationConfig, ParsedArguments)
├── AppDelegate.swift    # NSApplicationDelegate + UNUserNotificationCenterDelegate
├── Setup.swift          # Setup command + embedded notify.sh script
├── Doctor.swift         # Doctor command - diagnoses installation and permission issues
├── ArgumentParser.swift # CLI flag parsing and help text
└── Utilities.swift      # Helpers (exitWithError, terminateApp, focusITermSession)
```

**Key components:**
- **Constants**: Centralized magic strings (`claudeDirectory`, `sessionIdKey`, etc.)
- **Models**: `NotificationConfig` and `ParsedArguments` data structures
- **AppDelegate**: Handles notification display, authorization, and click responses
- **Setup**: Embedded `notify.sh` script + functions to configure `~/.claude/settings.json` hooks
- **Doctor**: Checks installation, hooks, permissions, and PATH configuration
- **ArgumentParser**: Parses `-t`, `-s`, `-m`, `-i` flags and `setup`/`doctor`/`help` subcommands
- **Utilities**: `exitWithError()`, `terminateApp()`, `focusITermSession()` via AppleScript

**Entry flow:** Parse args → configure NSApplication → show notification (if -m provided) → handle notification click → focus iTerm2 tab → exit

## CLI Usage

```bash
claude-notifier -m "Message" -t "Title" -s "Subtitle"
claude-notifier -m "Message" -i "$ITERM_SESSION_ID"  # With session ID for focus-on-click
claude-notifier setup    # Auto-configure Claude Code hooks
claude-notifier doctor   # Diagnose installation and permission issues
```

## Technical Notes

- Requires macOS 11.0+
- Uses native frameworks: AppKit, UserNotifications
- Makefile uses `swiftc` directly (not full SPM build) for the app bundle
- App is ad-hoc codesigned during build
- Runs as LSUIElement (no dock icon)
- Requires Automation permission for iTerm2 (prompted on first notification click)
