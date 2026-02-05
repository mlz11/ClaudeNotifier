import AppKit
import Foundation
import UserNotifications

// Note: `notifyScript` is defined in NotifyScript.generated.swift
// Generated at build time from Scripts/notify.sh

// MARK: - Setup Functions

func promptForConfigDirectory() -> URL {
    let defaultPath = "~/.claude"
    print("Claude config directory [\(defaultPath)]: ", terminator: "")
    fflush(stdout)

    if let input = readLine(), !input.isEmpty {
        return URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
    }

    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(Constants.claudeDirectory)
}

/// Returns true if notifications are authorized, false if denied
func requestNotificationPermissions() -> Bool {
    print("\nRequesting notification permissions...")

    let center = UNUserNotificationCenter.current()
    let semaphore = DispatchSemaphore(value: 0)
    var currentStatus: UNAuthorizationStatus = .notDetermined

    // Check current status first
    center.getNotificationSettings { settings in
        currentStatus = settings.authorizationStatus
        semaphore.signal()
    }
    semaphore.wait()

    switch currentStatus {
    case .authorized, .provisional:
        print("  Notifications: ✓")
        return true
    case .denied:
        print("  Notifications: denied")
        return false
    case .notDetermined:
        break // Will request below
    @unknown default:
        break
    }

    // Request authorization for first-time setup
    var granted = false
    center.requestAuthorization(options: [.alert, .sound, .badge]) { result, _ in
        granted = result
        semaphore.signal()
    }
    semaphore.wait()

    if granted {
        print("  Notifications: ✓")
        return true
    } else {
        print("  Notifications: denied")
        return false
    }
}

func requestTerminalPermissions() {
    print("\nRequesting terminal automation permissions...")
    print("  (You may see permission dialogs - please click OK to allow)")

    // Access windows/tabs to trigger the same permission as focusITermSession
    let terminals = [
        TerminalInfo(
            name: "iTerm2",
            bundleId: "com.googlecode.iterm2",
            script: """
            tell application "iTerm2"
                if (count of windows) > 0 then
                    get id of current session of current tab of current window
                end if
            end tell
            """
        ),
        TerminalInfo(
            name: "Terminal.app",
            bundleId: "com.apple.Terminal",
            script: """
            tell application "Terminal"
                if (count of windows) > 0 then
                    get tty of selected tab of front window
                end if
            end tell
            """
        )
    ]

    for terminal in terminals {
        // Check if app is running first
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == terminal.bundleId }

        if !isRunning {
            print("  \(terminal.name): skipped (not running)")
            continue
        }

        // Execute AppleScript - this will trigger permission dialog if needed
        if let script = NSAppleScript(source: terminal.script) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)

            if let err = error {
                let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
                if errorNum == -1743 {
                    print("  \(terminal.name): denied")
                    print("    → Open System Settings > Privacy & Security > Automation")
                    print("    → Enable ClaudeNotifier → \(terminal.name)")
                } else {
                    let errorMsg = err[NSAppleScript.errorMessage] as? String ?? "unknown"
                    print("  \(terminal.name): error (\(errorMsg))")
                }
            } else {
                print("  \(terminal.name): ✓")
            }
        }
    }
}

func ensureClaudeDirectoryExists(_ claudeDir: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: claudeDir.path) {
        do {
            try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            print("Created \(claudeDir.path)")
        } catch {
            exitWithError("Error creating \(claudeDir.path): \(error.localizedDescription)")
        }
    }
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

func addNotificationHooks(to settings: inout [String: Any], configDir: URL) {
    let notifyScriptPath = configDir.path + "/" + Constants.notifyScriptName
    let notificationHook: [String: Any] = [
        "matcher": "",
        "hooks": [
            ["type": "command", "command": "\(notifyScriptPath) input_needed"]
        ]
    ]
    let stopHook: [String: Any] = [
        "matcher": "",
        "hooks": [
            ["type": "command", "command": "\(notifyScriptPath) task_complete"]
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

/// Launch automation permission request in isolated process via `open`
/// This is necessary because apps launched from terminal inherit the terminal's context
/// and may bypass TCC permission checks
private func launchAutomationPermissionRequest() {
    // Find the app bundle path from the executable path
    // Resolve symlinks to handle Homebrew installations where CLI is a symlink
    let executablePath = CommandLine.arguments[0]
    let resolvedPath = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().path
    let appBundlePath: String

    if resolvedPath.contains(".app/Contents/MacOS/") {
        // Running from app bundle (directly or via symlink)
        appBundlePath = resolvedPath.components(separatedBy: "/Contents/MacOS/")[0]
    } else {
        // Fallback to default location
        appBundlePath = "/Applications/ClaudeNotifier.app"
    }

    guard FileManager.default.fileExists(atPath: appBundlePath) else {
        // App not installed, run directly (won't get proper permissions but better than nothing)
        requestTerminalPermissions()
        return
    }

    print("\nRequesting terminal automation permissions...")
    print("  (You may see permission dialogs - please click OK to allow)")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-W", appBundlePath, "--args", "--request-automation"]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        // Fallback to direct execution
        requestTerminalPermissions()
        return
    }

    // Verify permissions by checking if we can now execute AppleScript
    verifyTerminalPermissions()
}

/// Verify terminal permissions after the isolated process requested them
private func verifyTerminalPermissions() {
    let terminals: [(name: String, bundleId: String)] = [
        ("iTerm2", "com.googlecode.iterm2"),
        ("Terminal.app", "com.apple.Terminal")
    ]

    for terminal in terminals {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == terminal.bundleId }

        if !isRunning {
            print("  \(terminal.name): skipped (not running)")
            continue
        }

        // Permission was just requested in isolated process, so this should now work
        // or return -1743 if user denied
        let script = NSAppleScript(source: "tell application \"\(terminal.name)\" to return name")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let err = error {
            let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNum == -1743 {
                print("  \(terminal.name): denied")
            } else {
                print("  \(terminal.name): ✓")
            }
        } else {
            print("  \(terminal.name): ✓")
        }
    }
}

func runSetup() {
    let claudeDir = promptForConfigDirectory()
    ensureClaudeDirectoryExists(claudeDir)
    let settingsPath = claudeDir.appendingPathComponent(Constants.settingsFileName)

    writeNotifyScript(to: claudeDir)

    var settings = loadSettings(from: settingsPath)
    addNotificationHooks(to: &settings, configDir: claudeDir)
    writeSettings(settings, to: settingsPath)

    let notificationsGranted = requestNotificationPermissions()

    if !notificationsGranted {
        print("\nSetup incomplete: notification permission is required.")
        print("Please enable notifications for ClaudeNotifier:")
        print("  1. Open System Settings > Notifications > ClaudeNotifier")
        print("  2. Enable \"Allow Notifications\"")
        print("  3. Run 'claude-notifier setup' again")
        exit(1)
    }

    // Launch permission request in isolated process to properly trigger TCC dialogs
    launchAutomationPermissionRequest()

    print("\nSetup complete! Claude Code will now send notifications.")
    print("Clicking a notification will focus the terminal tab that triggered it.")
    print("Supported terminals: iTerm2, Terminal.app")
}
