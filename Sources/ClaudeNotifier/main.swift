import Foundation
import UserNotifications

let semaphore = DispatchSemaphore(value: 0)

// MARK: - Embedded notify.sh script

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

# Send notification with Claude icon
"$NOTIFIER" -t "$TITLE" -s "$REPO_NAME" -m "$MESSAGE"
"""

// MARK: - Setup Command

func runSetup() {
    let fileManager = FileManager.default
    let homeDir = fileManager.homeDirectoryForCurrentUser
    let claudeDir = homeDir.appendingPathComponent(".claude")
    let notifyPath = claudeDir.appendingPathComponent("notify.sh")
    let settingsPath = claudeDir.appendingPathComponent("settings.json")

    // Create ~/.claude directory if needed
    if !fileManager.fileExists(atPath: claudeDir.path) {
        do {
            try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            print("Created \(claudeDir.path)")
        } catch {
            fputs("Error creating \(claudeDir.path): \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    // Write notify.sh
    do {
        try notifyScript.write(to: notifyPath, atomically: true, encoding: .utf8)
        // Make executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: notifyPath.path)
        print("Installed \(notifyPath.path)")
    } catch {
        fputs("Error writing \(notifyPath.path): \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    // Read or create settings.json
    var settings: [String: Any] = [:]
    if fileManager.fileExists(atPath: settingsPath.path) {
        do {
            let data = try Data(contentsOf: settingsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = json
            }
        } catch {
            fputs("Warning: Could not parse existing settings.json, will create new one\n", stderr)
        }
    }

    // Define the hooks we want to add
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

    // Merge hooks into settings
    var hooks = settings["hooks"] as? [String: Any] ?? [:]
    hooks["Notification"] = [notificationHook]
    hooks["Stop"] = [stopHook]
    settings["hooks"] = hooks

    // Write settings.json
    do {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsPath)
        print("Updated \(settingsPath.path)")
    } catch {
        fputs("Error writing \(settingsPath.path): \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    print("\nSetup complete! Claude Code will now send notifications.")
}

// MARK: - Notification

func showNotification(title: String, subtitle: String?, body: String) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            let content = UNMutableNotificationContent()
            content.title = title
            if let sub = subtitle {
                content.subtitle = sub
            }
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { error in
                if let error = error {
                    fputs("Error: \(error.localizedDescription)\n", stderr)
                }
                semaphore.signal()
            }
        } else {
            fputs("Notification permission denied\n", stderr)
            semaphore.signal()
        }
    }
}

/// Parse arguments
let args = CommandLine.arguments

// Check for subcommands
if args.count >= 2 {
    switch args[1] {
    case "setup":
        runSetup()
        exit(0)
    case "-h", "--help", "help":
        print("""
        Usage: claude-notifier [command] [options]

        Commands:
          setup           Set up Claude Code integration (installs hooks)

        Options:
          -m "message"    The notification body (required for notifications)
          -t "title"      The notification title (default: "Claude")
          -s "subtitle"   The notification subtitle (optional)
          -h, --help      Show this help message
        """)
        exit(0)
    default:
        break
    }
}

var title = "Claude"
var subtitle: String?
var body = "Hello!"

var i = 1
while i < args.count {
    let arg = args[i]
    if arg == "-t", i + 1 < args.count {
        title = args[i + 1]
        i += 2
    } else if arg == "-s", i + 1 < args.count {
        subtitle = args[i + 1]
        i += 2
    } else if arg == "-m", i + 1 < args.count {
        body = args[i + 1]
        i += 2
    } else {
        i += 1
    }
}

showNotification(title: title, subtitle: subtitle, body: body)
semaphore.wait()
exit(0)
