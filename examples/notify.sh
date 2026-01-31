#!/bin/bash
# Claude Code notification script

EVENT_TYPE="$1"
NOTIFIER="/Applications/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"

# Check if we're in the currently focused iTerm2 tab
should_notify() {
    # Get our session ID (format: w0t0p0:UUID)
    [ -z "$ITERM_SESSION_ID" ] && return 0  # Not in iTerm2, always notify
    MY_SESSION="${ITERM_SESSION_ID#*:}"  # Extract UUID after colon

    # Check if iTerm2 is the frontmost app
    FRONTMOST=$(osascript -e 'tell application "System Events" to get bundle identifier of first process whose frontmost is true' 2>/dev/null)
    [ "$FRONTMOST" != "com.googlecode.iterm2" ] && return 0  # iTerm2 not focused, notify

    # Get the session ID of iTerm2's current session
    CURRENT_SESSION=$(osascript -e 'tell application "iTerm2" to tell current session of current window to return id' 2>/dev/null)

    # If sessions match, user is looking at this tab - don't notify
    [ "$MY_SESSION" = "$CURRENT_SESSION" ] && return 1

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

# Send notification with Claude icon
"$NOTIFIER" -t "$TITLE" -s "$REPO_NAME" -m "$MESSAGE"
