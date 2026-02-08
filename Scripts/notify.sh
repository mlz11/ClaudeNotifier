#!/bin/bash
# Claude Code notification script

EVENT_TYPE="$1"
NOTIFIER="claude-notifier"

# Read hook input from stdin (Claude Code passes JSON with notification_type)
# Skip idle_prompt — user was already notified when input was first needed
if [ ! -t 0 ]; then
    HOOK_INPUT=$(cat)
    case "$HOOK_INPUT" in
        *'"idle_prompt"'*)
            exit 0
            ;;
    esac
fi

# Get Terminal.app's tab TTY by walking up the process tree
# This handles cases where the user runs a nested terminal (tmux, qterm, etc.)
get_terminal_app_tty() {
    local pid=$$
    local current_tty
    local parent_tty

    current_tty=$(ps -p $pid -o tty= 2>/dev/null | tr -d ' ')

    # Walk up the process tree looking for the original TTY
    while [ -n "$pid" ] && [ "$pid" != "1" ]; do
        parent_tty=$(ps -p $pid -o tty= 2>/dev/null | tr -d ' ')
        if [ -n "$parent_tty" ] && [ "$parent_tty" != "??" ]; then
            current_tty="$parent_tty"
        fi
        pid=$(ps -p $pid -o ppid= 2>/dev/null | tr -d ' ')
    done

    # Return the TTY with /dev/ prefix
    if [ -n "$current_tty" ] && [ "$current_tty" != "??" ]; then
        echo "/dev/$current_tty"
    else
        tty  # Fallback to current tty
    fi
}

# Check if a given bundle ID matches the frontmost app
is_app_frontmost() {
    local bundle_id="$1"
    local frontmost
    frontmost=$(osascript -e 'tell application "System Events" to get bundle identifier of first process whose frontmost is true' 2>/dev/null)
    [ "$frontmost" = "$bundle_id" ]
}

# Detect terminal type and set session info
detect_terminal() {
    if [ -n "$ITERM_SESSION_ID" ]; then
        TERMINAL_TYPE="iterm2"
        SESSION_ID="$ITERM_SESSION_ID"
    elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
        TERMINAL_TYPE="terminal"
        SESSION_ID=$(get_terminal_app_tty)
    elif [ "$TERM_PROGRAM" = "zed" ]; then
        TERMINAL_TYPE="zed"
        SESSION_ID=""
    elif [ "$TERM_PROGRAM" = "ghostty" ]; then
        TERMINAL_TYPE="ghostty"
        SESSION_ID=""
    elif [ "$TERM_PROGRAM" = "WarpTerminal" ]; then
        TERMINAL_TYPE="warp"
        SESSION_ID=""
    elif [ "$TERM_PROGRAM" = "vscode" ]; then
        # Differentiate VS Code forks by their bundle identifier
        case "$__CFBundleIdentifier" in
            com.todesktop.230313mzl4w4u92)
                TERMINAL_TYPE="cursor"
                ;;
            com.vscodium)
                TERMINAL_TYPE="vscodium"
                ;;
            com.exafunction.windsurf)
                TERMINAL_TYPE="windsurf"
                ;;
            *)
                TERMINAL_TYPE="vscode"
                ;;
        esac
        SESSION_ID=""
    elif [ "$TERMINAL_EMULATOR" = "JetBrains-JediTerm" ]; then
        # Differentiate JetBrains IDEs by their bundle identifier
        case "$__CFBundleIdentifier" in
            com.jetbrains.intellij)
                TERMINAL_TYPE="intellij"
                ;;
            *)
                TERMINAL_TYPE="webstorm"
                ;;
        esac
        SESSION_ID=""
    else
        TERMINAL_TYPE=""
        SESSION_ID=""
    fi
}

# Check if we're in the currently focused terminal tab
should_notify() {
    detect_terminal

    case "$TERMINAL_TYPE" in
        iterm2)
            MY_SESSION="${ITERM_SESSION_ID#*:}"  # Extract UUID after colon
            is_app_frontmost "com.googlecode.iterm2" || return 0

            CURRENT_SESSION=$(osascript -e 'tell application "iTerm2" to tell current session of current window to return id' 2>/dev/null)
            [ "$MY_SESSION" = "$CURRENT_SESSION" ] && return 1
            ;;
        terminal)
            MY_TTY=$(get_terminal_app_tty)
            is_app_frontmost "com.apple.Terminal" || return 0

            CURRENT_TTY=$(osascript -e 'tell application "Terminal" to return tty of selected tab of front window' 2>/dev/null)
            [ "$MY_TTY" = "$CURRENT_TTY" ] && return 1
            ;;
        vscode)
            is_app_frontmost "com.microsoft.VSCode" && return 1
            ;;
        vscodium)
            is_app_frontmost "com.vscodium" && return 1
            ;;
        cursor)
            is_app_frontmost "com.todesktop.230313mzl4w4u92" && return 1
            ;;
        windsurf)
            is_app_frontmost "com.exafunction.windsurf" && return 1
            ;;
        zed)
            is_app_frontmost "dev.zed.Zed" && return 1
            ;;
        ghostty)
            is_app_frontmost "com.mitchellh.ghostty" && return 1
            ;;
        warp)
            is_app_frontmost "dev.warp.Warp-Stable" && return 1
            ;;
        webstorm)
            is_app_frontmost "com.jetbrains.WebStorm" && return 1
            ;;
        intellij)
            is_app_frontmost "com.jetbrains.intellij" && return 1
            ;;
        *)
            # Unknown terminal, always notify
            return 0
            ;;
    esac

    return 0  # Different tab, notify
}

# Skip notification if user is looking at this tab
if ! should_notify; then
    exit 0
fi

# Get repo name from git, fallback to directory name
REPO_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
REPO_NAME="${REPO_NAME:-$(basename "$PWD")}"

# Configure based on event type
case "$EVENT_TYPE" in
    "input_needed")
        TITLE="Claude Code"
        MESSAGE="Awaiting your input"
        ;;
    "task_complete")
        TITLE="Claude Code"
        MESSAGE="Task completed"
        ;;
    *)
        TITLE="Claude Code"
        MESSAGE="$EVENT_TYPE"
        ;;
esac

# Send notification with session info for focus-on-click
"$NOTIFIER" -t "$TITLE" -s "$REPO_NAME" -m "$MESSAGE" -i "$SESSION_ID" -T "$TERMINAL_TYPE" -S default
