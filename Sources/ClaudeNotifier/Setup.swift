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

func requestNotificationPermissions() {
    print("\nRequesting notification permissions...")

    let semaphore = DispatchSemaphore(value: 0)
    var granted = false

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { result, _ in
        granted = result
        semaphore.signal()
    }

    semaphore.wait()

    if granted {
        print("  Notifications: ✓")
    } else {
        print("  Notifications: denied (can enable in System Settings > Notifications)")
    }
}

func requestTerminalPermissions() {
    print("\nRequesting terminal automation permissions...")

    let terminals: [(name: String, script: String)] = [
        ("iTerm2", "tell application \"iTerm2\" to return name"),
        ("Terminal.app", "tell application \"Terminal\" to return name")
    ]

    for terminal in terminals {
        if let script = NSAppleScript(source: terminal.script) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)

            if let err = error {
                let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
                if errorNum == -1743 {
                    // User denied permission
                    print("  \(terminal.name): denied (can enable in System Settings > Privacy > Automation)")
                } else if errorNum == -600 || errorNum == -128 {
                    // App not running or user cancelled - permission may still be granted
                    print("  \(terminal.name): skipped (app not running)")
                } else if error != nil {
                    print("  \(terminal.name): skipped")
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

func runSetup() {
    let claudeDir = promptForConfigDirectory()
    ensureClaudeDirectoryExists(claudeDir)
    let settingsPath = claudeDir.appendingPathComponent(Constants.settingsFileName)

    writeNotifyScript(to: claudeDir)

    var settings = loadSettings(from: settingsPath)
    addNotificationHooks(to: &settings, configDir: claudeDir)
    writeSettings(settings, to: settingsPath)

    requestNotificationPermissions()
    requestTerminalPermissions()

    print("\nSetup complete! Claude Code will now send notifications.")
    print("Clicking a notification will focus the terminal tab that triggered it.")
    print("Supported terminals: iTerm2, Terminal.app")
}
