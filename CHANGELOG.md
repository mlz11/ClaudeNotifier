# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.14.0] - 2026-02-10

### Added

- Partial support for Claude Code IDE extensions (VS Code, Cursor, Windsurf, VSCodium, WebStorm, IntelliJ IDEA): task complete and permission request notifications work; input needed notifications are not available due to an upstream limitation
- `PermissionRequest` hook registration in setup and doctor checks
- Bundle ID fallback detection for extension context (when `TERM_PROGRAM` is unset)
- Duplicate notification guard for `PermissionRequest` events in terminal context

## [1.13.0] - 2026-02-10

### Added

- Notification deduplication: new notifications replace old ones per terminal tab per project instead of accumulating in Notification Center
- Source app name shown in notification title (e.g. "Claude Code · iTerm2")

## [1.12.0] - 2026-02-09

### Added

- Interactive `config` command for configuring icon color and notification sound preferences
- TUI menus render inline instead of clearing the screen

### Fixed

- Escape key now responds immediately in TUI menus

## [1.11.1] - 2026-02-09

### Fixed

- `icon` and `doctor` commands failing for Homebrew installations (app bundle not found)

## [1.11.0] - 2026-02-08

### Added

- Warp terminal support (app-level focus and suppression)

## [1.10.0] - 2026-02-08

### Added

- WebStorm terminal support (app-level focus and suppression)
- IntelliJ IDEA terminal support (app-level focus and suppression)

## [1.9.0] - 2026-02-07

### Added

- Structured logging with persistent log file
- `/file-issue` skill for creating GitHub issues

### Changed

- Moved `notify.sh` to `~/Library/Application Support/ClaudeNotifier/`

## [1.8.0] - 2026-02-07

### Added

- Ghostty terminal support (app-level focus and suppression)

## [1.7.0] - 2026-02-07

### Added

- VSCodium integrated terminal support (detection, suppression, focus-on-click)
- Exclude `*.generated.swift` files from lint and format

## [1.6.0] - 2026-02-07

### Added

- Cursor, Windsurf, and Zed editor support (detection, suppression, focus-on-click)
- VS Code integrated terminal support (detection, suppression, focus-on-click)
- System Events permission check during setup
- Group notifications by repo using thread identifiers
- `--version` flag and build-time version from VERSION file
- Status header to doctor command

### Changed

- Use Launch Services (`open -b`) instead of AppleScript for IDE editor focus — no Automation permission needed
- Differentiate Cursor/Windsurf from VS Code via `__CFBundleIdentifier` env var
- Only request Automation permission for iTerm2 and Terminal.app during setup

### Fixed

- `verifyTerminalPermissions` using display name instead of AppleScript name for VS Code
- Windsurf bundle ID corrected to `com.exafunction.windsurf`
- Reset script tolerates unregistered bundle IDs instead of aborting

## [1.5.0] - 2026-02-07

### Added

- Colored output for `make install`
- GitHub Actions workflow to attach `.app` zip to releases

### Fixed

- Command injection via `eval` in `make install` — replaced with safe tilde expansion
- Corrupted `settings.json` on interrupted write — now uses atomic write
- Warn user when `setup` replaces existing hooks
- Redundant terminal detection call in notify.sh
- Reject known flags as flag values in argument parser
- Safety timeout to prevent orphaned background processes
- Warn on valid but non-dictionary JSON in settings.json
- Default to unknown terminal type instead of assuming iTerm2
- Prevent reset script from exiting on first plist iteration
- Sanitize AppleScript string interpolation to prevent injection

### Changed

- Unified terminal definitions into TerminalType enum
- Extracted shared app bundle path resolution into Utilities
- Simplified command dispatch and argument models

## [1.4.1] - 2026-02-06

### Fixed

- Suppress duplicate "awaiting input" notifications caused by idle_prompt hook events

## [1.4.0] - 2026-02-06

### Added

- Colored CLI output for `setup`, `doctor`, and `icon` commands
- ANSI colors automatically disabled when output is piped

## [1.3.2] - 2026-02-05

### Fixed

- Automation permission dialog not appearing when running `claude-notifier` by command name (Homebrew)

## [1.3.1] - 2026-02-05

### Fixed

- Automation permission dialog not appearing when installed via Homebrew

## [1.3.0] - 2026-02-05

### Added

- Icon color variants: brown (default), blue, and green
- `icon` command to switch between icon variants (`claude-notifier icon blue`)
- `--default` flag to reset icon to default variant

### Changed

- Renamed `--reset` flag to `--default` for icon command

## [1.2.0] - 2026-02-04

### Added

- `doctor` command for diagnosing installation and permission issues
- `/reset` skill for complete uninstallation via Claude Code

### Fixed

- Doctor command no longer triggers automation permission prompts
- Launch automation permission request in isolated process
- Exit setup early when notification permission is denied
- Improve setup permission checks

## [1.1.0] - 2026-02-03

### Added

- Click-to-focus notifications: clicking a notification focuses the terminal tab that triggered it
- Terminal.app support for click-to-focus notifications
- Customizable notification sounds via `-S/--sound` flag
- Long-form CLI options (`--title`, `--subtitle`, `--message`, `--session-id`, `--sound`)
- Setup command (`claude-notifier setup`) for one-step Claude Code integration
- Prompt for notification permissions during setup
- Prompt for custom config directory during setup
- Prompt for custom install directory during setup
- Pre-commit hooks for linting and conventional commits
- SwiftLint and SwiftFormat configuration

### Fixed

- Terminal.app tab focus with nested terminals (tmux, qterm)
- App icon leg positions in SVG

### Changed

- Refactored single-file app into modular structure
- Extracted notify.sh to separate file with build-time codegen

## [1.0.0] - 2026-01-31

### Added

- Native macOS notification app with Claude's icon
- Smart notification suppression when terminal is focused
- CLI tool (`claude-notifier`) for triggering notifications
- Support for title, subtitle, and message via CLI flags
- Embedded icon (no Claude.app dependency)
- `make install` creates CLI symlink at `~/.local/bin/claude-notifier`
- PATH hint shown during install if needed

[1.14.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.14.0
[1.13.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.13.0
[1.12.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.12.0
[1.11.1]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.11.1
[1.11.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.11.0
[1.10.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.10.0
[1.9.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.9.0
[1.8.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.8.0
[1.7.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.7.0
[1.6.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.6.0
[1.5.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.5.0
[1.4.1]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.4.1
[1.4.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.4.0
[1.3.2]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.3.2
[1.3.1]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.3.1
[1.3.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.3.0
[1.2.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.2.0
[1.1.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.1.0
[1.0.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.0.0
