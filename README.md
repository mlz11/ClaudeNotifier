<p align="center">
  <img src="assets/icon.svg" alt="ClaudeNotifier Icon" width="128" height="128">
</p>

<h1 align="center">ClaudeNotifier</h1>

<p align="center">
  A macOS notification app for Claude Code integration.<br>
  Displays native notifications and focuses the correct terminal tab when clicked.
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

## ✨ Why ClaudeNotifier?

Anthropic's [recommended terminal notification setup](https://code.claude.com/docs/en/terminal-config#iterm-2-system-notifications) only works for iTerm2 users (also I could never make it work on my machine). ClaudeNotifier provides a reliable alternative that supports multiple terminals and editors, with extra features like click-to-focus and smart suppression.

Most other notification setups rely on `terminal-notifier` or `osascript` one-liners. ClaudeNotifier takes a different approach:

- 📦 **Zero dependencies**: Just install and run `claude-notifier setup`.
- 🎯 **Click-to-focus the exact tab**: Other tools open the app at best. ClaudeNotifier focuses the specific terminal tab or iTerm2 session that triggered the notification.
- 🤫 **Smart suppression**: Notifications are silenced when you're already looking at the terminal, so you're not interrupted mid-thought.
- 🖥️ **Wide terminal support**: [iTerm2](https://iterm2.com/), [Terminal.app](https://support.apple.com/guide/terminal/welcome/mac), [Ghostty](https://ghostty.org/), [Warp](https://www.warp.dev/), [VS Code](https://code.visualstudio.com/), [VSCodium](https://vscodium.com/), [Cursor](https://cursor.com/home), [Windsurf](https://codeium.com/windsurf), [Zed](https://zed.dev/), [WebStorm](https://www.jetbrains.com/webstorm/), and [IntelliJ IDEA](https://www.jetbrains.com/idea/).
- 🩺 **Built-in diagnostics**: `claude-notifier doctor` checks your installation, hooks, permissions, and PATH so you can fix issues without guesswork.
- 💅🏻 **A pretty icon**: Look, someone spent way too long on it. Might as well enjoy it.

## 📦 Installation

<details open>
<summary><strong>Homebrew (Recommended)</strong></summary>

```bash
brew install --cask mlz11/tap/claude-notifier
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
- Prompts for required macOS permissions

  <details>
  <summary>🔐 <em>Permissions details</em></summary>
  1. **Notifications**: Required to display notifications.
     - Manage in: **System Settings → Notifications → ClaudeNotifier**

  2. **Automation**: Required for click-to-focus.
     - Manage in: **System Settings → Privacy & Security → Automation → ClaudeNotifier**

  3. **System Events**: Required for smart suppression. Most terminals (like iTerm2) typically have this permission already, but others (like VS Code) may prompt you to allow it to control System Events on first use.
     - Manage in: **System Settings → Privacy & Security → Automation → [Your terminal or IDE]**

  </details>

### Diagnosing Issues

```bash
claude-notifier doctor
```

This checks your installation and permissions, showing any issues and how to fix them.

### Configuring Preferences

```bash
claude-notifier config
```

Opens an interactive menu to configure icon color and notification sound.

```
  ClaudeNotifier Configuration
  ↑/↓ navigate · Enter select · Esc back

    ❯ Icon color
      Notification sound
      Done
```

Available icon variants:

<div align="center">

|                 brown (default)                  |                      blue                       |                      green                       |
| :----------------------------------------------: | :---------------------------------------------: | :----------------------------------------------: |
| <img src="assets/previews/brown.png" width="64"> | <img src="assets/previews/blue.png" width="64"> | <img src="assets/previews/green.png" width="64"> |

</div>

## Requirements

- macOS 11.0+
- iTerm2, Terminal.app, Ghostty, Warp, VS Code, VSCodium, Cursor, Windsurf, Zed, WebStorm, or IntelliJ IDEA

## ❓ FAQ

<details>
<summary><strong>Why aren't all terminals fully supported (tab-specific focus) like iTerm2?</strong></summary>

Full support (tab-specific focus and suppression) requires two things from the terminal: AppleScript integration and a session ID environment variable. Currently only iTerm2 and Terminal.app provide both.

#### IDE editors (VS Code, VSCodium, Cursor, Windsurf, Zed, WebStorm, IntelliJ IDEA)

These editors have **app-level support only**:

- **App-level suppression**: Notifications are suppressed whenever the editor is frontmost, even if you're in the editor rather than the terminal panel. These editors don't expose which panel is focused via AppleScript or environment variables.
- **No tab-specific focus**: Clicking a notification brings the editor to the foreground but cannot focus a specific terminal instance.

These are upstream limitations, not something ClaudeNotifier can work around without companion extensions.

#### Ghostty

Ghostty also has **app-level support only**, for different reasons (it lacks the APIs needed for full integration):

- No session ID environment variable ([discussion](https://github.com/ghostty-org/ghostty/discussions/9084))
- AppleScript support is planned but not yet implemented ([discussion](https://github.com/ghostty-org/ghostty/discussions/2353))

Once Ghostty adds both, we can upgrade to full support with tab-specific focus and suppression.

#### Warp

Warp also has **app-level support only**. It does not support AppleScript and doesn't expose a session ID environment variable, so tab-specific focus and suppression are not possible.

- [AppleScript support request](https://github.com/warpdotdev/Warp/issues/3364)
- [Scripting & CLI discussion](https://github.com/warpdotdev/Warp/discussions/612)

</details>

<details>
<summary><strong>Does it work with the Claude desktop app?</strong></summary>

Partially. Claude Desktop's **Code tab** works with ClaudeNotifier because it runs the same Claude Code engine (hooks fire normally).

The **Chat and Cowork tabs** are not supported. ClaudeNotifier hooks into Claude Code's lifecycle events (Notification/Stop hooks), which only fire when the Claude Code engine is running. Chat and Cowork tabs don't use Claude Code's hook system, and the Electron-based desktop app doesn't expose an API or observable event for detecting when a response completes.

This would require Anthropic to add native notification support or expose hooks for prompt completion in those modes.

</details>
