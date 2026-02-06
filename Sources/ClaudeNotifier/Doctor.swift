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

func checkTerminalAutomationPermissions() -> [CheckResult] {
    // Check which terminal apps are running
    let runningApps = NSWorkspace.shared.runningApplications
    let runningTerminals = TerminalType.supported.filter { terminal in
        guard let bundleId = terminal.bundleId else { return false }
        return runningApps.contains { $0.bundleIdentifier == bundleId }
    }

    if runningTerminals.isEmpty {
        return [CheckResult(
            passed: true,
            message: "Automation: no supported terminals running"
        )]
    }

    // Report which terminals are running - permission will be requested on first notification click
    let terminalNames = runningTerminals.map(\.displayName).joined(separator: ", ")
    return [CheckResult(
        passed: true,
        message: "Automation: \(terminalNames) running, permission will be requested on first notification click"
    )]
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
    print("\(header("ClaudeNotifier Diagnostics"))\n")

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
            print("  \(success("✓")) \(result.message)")
        } else {
            print("  \(error("✗")) \(result.message)")
            if let remediation = result.remediation {
                for line in remediation.split(separator: "\n") {
                    print("    \(warning("→ \(line)"))")
                }
            }
            issues += 1
        }
    }

    // Summary
    print("")
    if issues == 0 {
        print(successBold("All checks passed!") + " ClaudeNotifier is properly configured.")
    } else {
        print(errorBold("\(issues) issue\(issues == 1 ? "" : "s") found."))
        print("Run '\(info("claude-notifier setup"))' to fix configuration issues.")
        exit(1)
    }
}
