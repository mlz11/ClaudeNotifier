import Foundation

// MARK: - Embedded notify.sh script

// swiftlint:disable line_length
let notifyScript = """
#!/bin/bash
# Claude Code notification script

EVENT_TYPE="$1"
NOTIFIER="claude-notifier"

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

# Send notification with Claude icon and session ID for focus-on-click
"$NOTIFIER" -t "$TITLE" -s "$REPO_NAME" -m "$MESSAGE" -i "$ITERM_SESSION_ID"
"""
// swiftlint:enable line_length

// MARK: - Setup Functions

func ensureClaudeDirectoryExists() -> URL {
    let fileManager = FileManager.default
    let claudeDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(Constants.claudeDirectory)

    if !fileManager.fileExists(atPath: claudeDir.path) {
        do {
            try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            print("Created \(claudeDir.path)")
        } catch {
            exitWithError("Error creating \(claudeDir.path): \(error.localizedDescription)")
        }
    }

    return claudeDir
}

func writeNotifyScript(to directory: URL) {
    let notifyPath = directory.appendingPathComponent(Constants.notifyScriptName)

    do {
        try notifyScript.write(to: notifyPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: notifyPath.path)
        print("Installed \(notifyPath.path)")
    } catch {
        exitWithError("Error writing \(notifyPath.path): \(error.localizedDescription)")
    }
}

func loadSettings(from path: URL) -> [String: Any] {
    guard FileManager.default.fileExists(atPath: path.path) else {
        return [:]
    }

    do {
        let data = try Data(contentsOf: path)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
    } catch {
        fputs("Warning: Could not parse existing settings.json, will create new one\n", stderr)
    }

    return [:]
}

func addNotificationHooks(to settings: inout [String: Any]) {
    let notificationHook: [String: Any] = [
        "matcher": "",
        "hooks": [
            ["type": "command", "command": "~/.claude/notify.sh input_needed"]
        ]
    ]
    let stopHook: [String: Any] = [
        "matcher": "",
        "hooks": [
            ["type": "command", "command": "~/.claude/notify.sh task_complete"]
        ]
    ]

    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    hooks["Notification"] = [notificationHook]
    hooks["Stop"] = [stopHook]
    settings["hooks"] = hooks
}

func writeSettings(_ settings: [String: Any], to path: URL) {
    do {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: path)
        print("Updated \(path.path)")
    } catch {
        exitWithError("Error writing \(path.path): \(error.localizedDescription)")
    }
}

func runSetup() {
    let claudeDir = ensureClaudeDirectoryExists()
    let settingsPath = claudeDir.appendingPathComponent(Constants.settingsFileName)

    writeNotifyScript(to: claudeDir)

    var settings = loadSettings(from: settingsPath)
    addNotificationHooks(to: &settings)
    writeSettings(settings, to: settingsPath)

    print("\nSetup complete! Claude Code will now send notifications.")
    print("Clicking a notification will focus the iTerm2 tab that triggered it.")
}
