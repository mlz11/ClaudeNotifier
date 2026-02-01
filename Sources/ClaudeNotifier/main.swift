import AppKit
import UserNotifications

// MARK: - Constants

enum Constants {
    static let defaultTitle = "Claude"
    static let claudeDirectory = ".claude"
    static let notifyScriptName = "notify.sh"
    static let settingsFileName = "settings.json"
    static let sessionIdKey = "sessionId"
}

// MARK: - Types

struct NotificationConfig {
    let title: String
    let subtitle: String?
    let body: String
    let sessionId: String?
}

struct ParsedArguments {
    let command: String?
    let title: String
    let subtitle: String?
    let body: String?
    let sessionId: String?
}

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

// MARK: - App Lifecycle Helpers

func exitWithError(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

func terminateApp(afterDelay delay: Double = 0) {
    if delay > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { NSApp.terminate(nil) }
    } else {
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

// MARK: - Setup Command

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

// MARK: - iTerm2 Focus

func focusITermSession(_ sessionId: String) {
    // The session ID from ITERM_SESSION_ID is in format "w0t0p0:UUID"
    // We need the UUID part to match against iTerm2's session id
    let targetId = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId

    guard !targetId.isEmpty else { return }

    let scriptSource = """
    tell application "iTerm2"
        activate
        repeat with w in windows
            tell w
                repeat with t in tabs
                    repeat with s in sessions of t
                        if id of s is "\(targetId)" then
                            select t
                        end if
                    end repeat
                end repeat
            end tell
        end repeat
    end tell
    """

    if let script = NSAppleScript(source: scriptSource) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var notificationConfig: NotificationConfig?

    func applicationDidFinishLaunching(_: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // If we have a notification to show, show it
        if let config = notificationConfig {
            showNotification(
                title: config.title,
                subtitle: config.subtitle,
                body: config.body,
                sessionId: config.sessionId
            )
        } else {
            // Launched without notification config (e.g., from notification click)
            // The delegate method will handle the notification response
            // Give a brief moment for notification response to be delivered, then exit
            terminateApp(afterDelay: 0.5)
        }
    }

    func showNotification(title: String, subtitle: String?, body: String, sessionId: String?) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                if let sub = subtitle {
                    content.subtitle = sub
                }
                content.body = body
                content.sound = .default

                // Store session ID for focus-on-click
                if let sid = sessionId, !sid.isEmpty {
                    content.userInfo = [Constants.sessionIdKey: sid]
                }

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request) { _ in
                    terminateApp()
                }
            } else {
                fputs("Notification permission denied\n", stderr)
                terminateApp()
            }
        }
    }

    /// Called when user clicks on notification
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let sessionId = response.notification.request.content.userInfo[Constants.sessionIdKey] as? String {
            focusITermSession(sessionId)
        }
        completionHandler()
        terminateApp()
    }

    /// Allow notifications to show even when app is in foreground
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Argument Parsing

func parseArguments() -> ParsedArguments {
    let args = CommandLine.arguments

    // Check for subcommands
    if args.count >= 2 {
        switch args[1] {
        case "setup":
            return ParsedArguments(command: "setup", title: "", subtitle: nil, body: nil, sessionId: nil)
        case "-h", "--help", "help":
            return ParsedArguments(command: "help", title: "", subtitle: nil, body: nil, sessionId: nil)
        default:
            break
        }
    }

    var title = Constants.defaultTitle
    var subtitle: String?
    var body: String?
    var sessionId: String?

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
        } else if arg == "-i", i + 1 < args.count {
            sessionId = args[i + 1]
            i += 2
        } else {
            i += 1
        }
    }

    return ParsedArguments(command: nil, title: title, subtitle: subtitle, body: body, sessionId: sessionId)
}

func showHelp() {
    print("""
    Usage: claude-notifier [command] [options]

    Commands:
      setup           Set up Claude Code integration (installs hooks)

    Options:
      -m "message"    The notification body (required for notifications)
      -t "title"      The notification title (default: "Claude")
      -s "subtitle"   The notification subtitle (optional)
      -i "session"    iTerm2 session ID for focus-on-click (optional)
      -h, --help      Show this help message
    """)
}

// MARK: - Main

let parsed = parseArguments()

if parsed.command == "setup" {
    runSetup()
    exit(0)
}

if parsed.command == "help" {
    showHelp()
    exit(0)
}

// Create and configure the app
let app = NSApplication.shared
let delegate = AppDelegate()

// Only set notification config if we have a message to show
if let body = parsed.body {
    delegate.notificationConfig = NotificationConfig(
        title: parsed.title,
        subtitle: parsed.subtitle,
        body: body,
        sessionId: parsed.sessionId
    )
}

app.delegate = delegate
app.setActivationPolicy(.accessory) // Run as background app (no dock icon)
app.run()
