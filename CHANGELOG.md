# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.3.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.3.0
[1.2.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.2.0
[1.1.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.1.0
[1.0.0]: https://github.com/mlz11/ClaudeNotifier/releases/tag/v1.0.0
