import AppKit
import Foundation
import UserNotifications

// MARK: - Check Result

struct CheckResult {
    let passed: Bool
    let message: String
    let remediation: String?

    init(passed: Bool, message: String, remediation: String? = nil) {
        self.passed = passed
        self.message = message
        self.remediation = remediation
    }
}

// MARK: - Installation Checks

func checkAppInstallation() -> CheckResult {
    let cliSymlink = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin/claude-notifier")

    // Check if CLI symlink exists
    guard FileManager.default.fileExists(atPath: cliSymlink.path) else {
        return CheckResult(
            passed: false,
            message: "CLI symlink not found",
            remediation: "Run 'make install' to create symlink at ~/.local/bin/claude-notifier"
        )
    }

    // Check if symlink is valid (points to existing file)
    guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: cliSymlink.path),
          FileManager.default.fileExists(atPath: target)
    else {
        return CheckResult(
            passed: false,
            message: "CLI symlink is broken",
            remediation: "Run 'make install' to recreate symlink"
        )
    }

    // Extract app path from symlink target to verify app bundle
    if target.contains("/ClaudeNotifier.app/") {
        if let range = target.range(of: "/Contents/MacOS/") {
            let appPath = String(target[..<range.lowerBound])
            return CheckResult(passed: true, message: "App installed at \(appPath)")
        }
    }

    return CheckResult(passed: true, message: "CLI symlink: valid")
}

func checkNotifyScript() -> CheckResult {
    let scriptPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(Constants.claudeDirectory)
        .appendingPathComponent(Constants.notifyScriptName)

    guard FileManager.default.fileExists(atPath: scriptPath.path) else {
        return CheckResult(
            passed: false,
            message: "notify.sh not found",
            remediation: "Run 'claude-notifier setup' to install script"
        )
    }

    guard FileManager.default.isExecutableFile(atPath: scriptPath.path) else {
        return CheckResult(
            passed: false,
            message: "notify.sh is not executable",
            remediation: "Run 'chmod +x ~/.claude/notify.sh' or 'claude-notifier setup'"
        )
    }

    return CheckResult(passed: true, message: "notify.sh: installed and executable")
}

// MARK: - Configuration Checks

func checkSettingsHooks() -> CheckResult {
    let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(Constants.claudeDirectory)
        .appendingPathComponent(Constants.settingsFileName)

    guard FileManager.default.fileExists(atPath: settingsPath.path) else {
        return CheckResult(
            passed: false,
            message: "settings.json not found",
            remediation: "Run 'claude-notifier setup' to create configuration"
        )
    }

    do {
        let data = try Data(contentsOf: settingsPath)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any]
        else {
            return CheckResult(
                passed: false,
                message: "No hooks configured in settings.json",
                remediation: "Run 'claude-notifier setup' to add hooks"
            )
        }

        let hasNotificationHook = hooks["Notification"] != nil
        let hasStopHook = hooks["Stop"] != nil

        if !hasNotificationHook || !hasStopHook {
            let missing = [
                !hasNotificationHook ? "Notification" : nil,
                !hasStopHook ? "Stop" : nil
            ].compactMap { $0 }

            return CheckResult(
                passed: false,
                message: "Missing hooks: \(missing.joined(separator: ", "))",
                remediation: "Run 'claude-notifier setup' to add missing hooks"
            )
        }

        return CheckResult(passed: true, message: "Hooks: configured")

    } catch {
        return CheckResult(
            passed: false,
            message: "Failed to parse settings.json",
            remediation: "Run 'claude-notifier setup' to recreate configuration"
        )
    }
}

// MARK: - Permission Checks

func checkNotificationPermissions() -> CheckResult {
    let center = UNUserNotificationCenter.current()
    let semaphore = DispatchSemaphore(value: 0)
    var status: UNAuthorizationStatus = .notDetermined

    center.getNotificationSettings { settings in
        status = settings.authorizationStatus
        semaphore.signal()
    }
    semaphore.wait()

    switch status {
    case .authorized, .provisional:
        return CheckResult(passed: true, message: "Notifications: authorized")
    case .denied:
        return CheckResult(
            passed: false,
            message: "Notifications: denied",
            remediation: """
            Open System Settings > Notifications > ClaudeNotifier
            Enable "Allow Notifications"
            """
        )
    case .notDetermined:
        return CheckResult(
            passed: false,
            message: "Notifications: not configured",
            remediation: "Run 'claude-notifier setup' to request permissions"
        )
    @unknown default:
        return CheckResult(
            passed: false,
            message: "Notifications: unknown status",
            remediation: "Run 'claude-notifier setup' to configure"
        )
    }
}

/// Internal function that runs AppleScript checks - called from isolated process
/// Writes results to a temp file passed via --output argument
func runAutomationChecks() {
    // Get output file path from arguments
    let args = CommandLine.arguments
    var outputPath: String?
    if let idx = args.firstIndex(of: "--output"), idx + 1 < args.count {
        outputPath = args[idx + 1]
    }

    // Use the same scripts as setup to properly trigger TCC check
    let terminals: [TerminalInfo] = [
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

    var results: [String] = []

    for terminal in terminals {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == terminal.bundleId }

        if !isRunning {
            results.append("\(terminal.name):skipped")
            continue
        }

        guard let script = NSAppleScript(source: terminal.script) else {
            results.append("\(terminal.name):error")
            continue
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if let err = error {
            let errorNum = err[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNum == -1743 {
                results.append("\(terminal.name):denied")
            } else {
                results.append("\(terminal.name):error")
            }
        } else {
            results.append("\(terminal.name):allowed")
        }
    }

    // Write results to output file or stdout
    let output = results.joined(separator: "\n")
    if let path = outputPath {
        try? output.write(toFile: path, atomically: true, encoding: .utf8)
    } else {
        print(output)
    }
}

private func parseAutomationResult(name: String, status: String) -> CheckResult? {
    switch status {
    case "allowed":
        return CheckResult(passed: true, message: "\(name): automation allowed")
    case "denied":
        return CheckResult(
            passed: false,
            message: "\(name): automation denied",
            remediation: "System Settings > Privacy & Security > Automation > Enable ClaudeNotifier -> \(name)"
        )
    case "skipped":
        return CheckResult(passed: true, message: "\(name): skipped (not running)")
    case "error":
        return CheckResult(
            passed: false,
            message: "\(name): automation error",
            remediation: "Try running 'claude-notifier setup' again"
        )
    default:
        return nil
    }
}

private func getAppBundlePath() -> String {
    let executablePath = CommandLine.arguments[0]
    if executablePath.contains(".app/Contents/MacOS/") {
        return executablePath.components(separatedBy: "/Contents/MacOS/")[0]
    }
    return "/Applications/ClaudeNotifier.app"
}

func checkTerminalAutomationPermissions() -> [CheckResult] {
    let appBundlePath = getAppBundlePath()

    guard FileManager.default.fileExists(atPath: appBundlePath) else {
        return [CheckResult(
            passed: true,
            message: "Automation: cannot verify (app bundle not found)",
            remediation: "Run 'make install' first, then check automation permissions"
        )]
    }

    // Create temp file and launch isolated process for accurate TCC check
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("claude-notifier-check-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-W", appBundlePath, "--args", "--check-automation", "--output", tempFile.path]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return [CheckResult(
            passed: true,
            message: "Automation: cannot verify (failed to launch)",
            remediation: "Run 'claude-notifier setup' to configure permissions"
        )]
    }

    guard let output = try? String(contentsOf: tempFile, encoding: .utf8) else {
        return [CheckResult(
            passed: true,
            message: "Automation: cannot verify (no output)",
            remediation: "Run 'claude-notifier setup' to configure permissions"
        )]
    }

    let results: [CheckResult] = output.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: ":")
        guard parts.count == 2 else { return nil }
        return parseAutomationResult(name: String(parts[0]), status: String(parts[1]))
    }

    return results.isEmpty
        ? [CheckResult(passed: true, message: "Automation: no terminals running to check")]
        : results
}

// MARK: - Environment Checks

func checkPATHConfiguration() -> CheckResult {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else {
        return CheckResult(
            passed: true,
            message: "PATH: could not determine"
        )
    }

    let binDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin")
        .path

    if path.split(separator: ":").contains(where: { String($0) == binDir }) {
        return CheckResult(passed: true, message: "PATH: ~/.local/bin included")
    } else {
        return CheckResult(
            passed: false,
            message: "~/.local/bin not in PATH",
            remediation: """
            Add to your shell config (~/.zshrc or ~/.bashrc):
            export PATH="$HOME/.local/bin:$PATH"
            """
        )
    }
}

// MARK: - Main Doctor Command

func runDoctor() {
    print("ClaudeNotifier Diagnostics\n")

    var issues = 0

    // Collect all check results
    let checks: [CheckResult] = [
        checkAppInstallation(),
        checkNotifyScript(),
        checkSettingsHooks(),
        checkNotificationPermissions()
    ] + checkTerminalAutomationPermissions() + [
        checkPATHConfiguration()
    ]

    // Problem-focused output
    for result in checks {
        if result.passed {
            print("  ✓ \(result.message)")
        } else {
            print("  ✗ \(result.message)")
            if let remediation = result.remediation {
                for line in remediation.split(separator: "\n") {
                    print("    → \(line)")
                }
            }
            issues += 1
        }
    }

    // Summary
    print("")
    if issues == 0 {
        print("All checks passed! ClaudeNotifier is properly configured.")
    } else {
        print("\(issues) issue\(issues == 1 ? "" : "s") found.")
        print("Run 'claude-notifier setup' to fix configuration issues.")
        exit(1)
    }
}
