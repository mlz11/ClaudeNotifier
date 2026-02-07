import AppKit
import Foundation
import UserNotifications

// Note: `notifyScript` is defined in NotifyScript.generated.swift
// Generated at build time from Scripts/notify.sh

// MARK: - Setup Functions

func promptForConfigDirectory() -> URL {
    let defaultPath = "~/.claude"
    print("Claude config directory [\(hint(defaultPath))]: ", terminator: "")
    fflush(stdout)

    if let input = readLine(), !input.isEmpty {
        return URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
    }

    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(Constants.claudeDirectory)
}

/// Returns true if notifications are authorized, false if denied
func requestNotificationPermissions() -> Bool {
    print("\n\(info("Requesting notification permissions..."))")

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
        print("  \(success("Notifications: ✓"))")
        return true
    case .denied:
        print("  \(error("Notifications: denied"))")
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
        print("  \(success("Notifications: ✓"))")
        return true
    } else {
        print("  \(error("Notifications: denied"))")
        return false
    }
}

func requestTerminalPermissions() {
    print("\n\(info("Requesting terminal automation permissions..."))")
    print("  \(hint("(You may see permission dialogs - please click OK to allow)"))")

    // Access windows/tabs to trigger the same permission as focusITermSession
    let runningApps = NSWorkspace.shared.runningApplications

    for terminal in TerminalType.supported {
        guard let bundleId = terminal.bundleId,
              let script = terminal.permissionCheckScript
        else { continue }

        // Check if app is running first
        let isRunning = runningApps.contains { $0.bundleIdentifier == bundleId }

        if !isRunning {
            print("  \(hint("\(terminal.displayName): skipped (not running)"))")
            continue
        }

        // Execute AppleScript - this will trigger permission dialog if needed
        if let appleScript = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            appleScript.executeAndReturnError(&errorDict)

            if let err = errorDict {
                let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
                if errorNum == -1743 {
                    print("  \(error("\(terminal.displayName): denied"))")
                    print("    \(warning("→ Open System Settings > Privacy & Security > Automation"))")
                    print("    \(warning("→ Enable ClaudeNotifier → \(terminal.displayName)"))")
                } else {
                    let errorMsg = err[NSAppleScript.errorMessage] as? String ?? "unknown"
                    print("  \(error("\(terminal.displayName): error (\(errorMsg))"))")
                }
            } else {
                print("  \(success("\(terminal.displayName): ✓"))")
            }
        }
    }
}

func ensureClaudeDirectoryExists(_ claudeDir: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: claudeDir.path) {
        do {
            try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            print(success("Created \(claudeDir.path)"))
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
        print(success("Installed \(notifyPath.path)"))
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
        fputs("Warning: settings.json is not a JSON object, will create new one\n", stderr)
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

    warnIfExistingHooks(hooks, key: "Notification")
    warnIfExistingHooks(hooks, key: "Stop")

    hooks["Notification"] = [notificationHook]
    hooks["Stop"] = [stopHook]
    settings["hooks"] = hooks
}

/// Warn the user if existing hooks will be overwritten
private func warnIfExistingHooks(_ hooks: [String: Any], key: String) {
    guard let existing = hooks[key] as? [[String: Any]], !existing.isEmpty else { return }

    print(warning("Existing \(key) hooks will be replaced:"))
    for entry in existing {
        if let innerHooks = entry["hooks"] as? [[String: Any]] {
            for hook in innerHooks {
                let command = hook["command"] as? String ?? "unknown"
                print("  \(warning("→ \(command)"))")
            }
        }
    }
}

func writeSettings(_ settings: [String: Any], to path: URL) {
    do {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: path, options: .atomic)
        print(success("Updated \(path.path)"))
    } catch {
        exitWithError("Error writing \(path.path): \(error.localizedDescription)")
    }
}

/// Launch automation permission request in isolated process via `open`
/// This is necessary because apps launched from terminal inherit the terminal's context
/// and may bypass TCC permission checks
private func launchAutomationPermissionRequest() {
    // Find the app bundle path from the executable path
    // Handle multiple scenarios:
    // 1. Direct execution: ./build/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier
    // 2. Symlink execution: ~/.local/bin/claude-notifier -> /Applications/...
    // 3. Homebrew: claude-notifier (just command name, need to find via which)
    let executablePath = CommandLine.arguments[0]
    var resolvedPath: String

    if executablePath.contains("/") {
        // Path contains directory separator, resolve it directly
        resolvedPath = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().path
    } else {
        // Just a command name (e.g., "claude-notifier"), find it via PATH
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = [executablePath]
        let pipe = Pipe()
        which.standardOutput = pipe
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let pathString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !pathString.isEmpty {
                resolvedPath = URL(fileURLWithPath: pathString).resolvingSymlinksInPath().path
            } else {
                resolvedPath = executablePath
            }
        } catch {
            resolvedPath = executablePath
        }
    }

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

    print("\n\(info("Requesting terminal automation permissions..."))")
    print("  \(hint("(You may see permission dialogs - please click OK to allow)"))")

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
    let runningApps = NSWorkspace.shared.runningApplications

    for terminal in TerminalType.supported {
        guard let bundleId = terminal.bundleId else { continue }

        // Only terminals that use AppleScript need Automation permission
        guard terminal.permissionCheckScript != nil else { continue }

        let isRunning = runningApps.contains { $0.bundleIdentifier == bundleId }

        if !isRunning {
            print("  \(hint("\(terminal.displayName): skipped (not running)"))")
            continue
        }

        // Permission was just requested in isolated process, so this should now work
        // or return -1743 if user denied
        let script = NSAppleScript(source: "tell application \"\(terminal.appleScriptName)\" to return name")
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)

        if let err = errorDict {
            let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNum == -1743 {
                print("  \(error("\(terminal.displayName): denied"))")
            } else {
                print("  \(success("\(terminal.displayName): ✓"))")
            }
        } else {
            print("  \(success("\(terminal.displayName): ✓"))")
        }
    }
}

/// Request System Events permission by spawning osascript as a child process.
/// macOS attributes TCC permissions to the responsible GUI app (the terminal),
/// so this triggers the correct "Terminal → System Events" permission prompt.
func requestSystemEventsPermission() {
    print("\n\(info("Checking System Events permission..."))")
    print("  \(hint("(Required for smart notification suppression)"))")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
        "-e",
        "tell application \"System Events\" to get bundle identifier of first process whose frontmost is true"
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("  \(success("System Events: ✓"))")
            print("  \(hint("Note: this only covers the current terminal. Other terminals (e.g. VS Code)"))")
            print("  \(hint("will prompt for System Events permission on first notification."))")
        } else {
            print("  \(error("System Events: denied"))")
            print("    \(warning("→ Open System Settings > Privacy & Security > Automation"))")
            print("    \(warning("→ Enable your terminal → System Events"))")
        }
    } catch let err {
        print("  \(error("System Events: could not check (\(err.localizedDescription))"))")
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
        print("\n\(errorBold("Setup incomplete: notification permission is required."))")
        print(warning("Please enable notifications for ClaudeNotifier:"))
        print("  1. Open System Settings > Notifications > ClaudeNotifier")
        print("  2. Enable \"Allow Notifications\"")
        print("  3. Run '\(info("claude-notifier setup"))' again")
        exit(1)
    }

    requestSystemEventsPermission()

    // Launch permission request in isolated process to properly trigger TCC dialogs
    launchAutomationPermissionRequest()

    print("\n\(successBold("Setup complete!")) Claude Code will now send notifications.")
    print("Clicking a notification will focus the terminal tab that triggered it.")
    print(hint("Supported terminals: iTerm2, Terminal.app, VS Code, Cursor, Windsurf, Zed, Ghostty"))
}
