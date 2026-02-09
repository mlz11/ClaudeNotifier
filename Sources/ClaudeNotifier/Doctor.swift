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
    if let appPath = getInstalledAppPath() {
        return CheckResult(passed: true, message: "App installed at \(appPath.path)")
    }

    return CheckResult(
        passed: false,
        message: "ClaudeNotifier.app not found",
        remediation: "Install via 'brew install mlz11/tap/claude-notifier' or 'make install'"
    )
}

func checkNotifyScript() -> CheckResult {
    let scriptPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(Constants.appSupportDirectory)
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
            remediation: "Run 'chmod +x ~/\(Constants.appSupportDirectory)/notify.sh' or 'claude-notifier setup'"
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

func printStatusHeader() {
    // Version
    let versionLine = "ClaudeNotifier \(info("v\(Constants.version)"))"

    // App location (resolve from running binary)
    let appLocation = Bundle.main.bundlePath

    // Icon variant
    let iconLabel: String
    if let variant = getCurrentVariant() {
        iconLabel = variant == IconVariant.defaultVariant
            ? "\(variant.rawValue) \(hint("(default)"))"
            : variant.rawValue
    } else {
        iconLabel = hint("unknown")
    }

    // Sound config
    let config = loadConfig()
    let soundLabel = soundDisplayName(config.sound)

    print(versionLine)
    print("  App:   \(appLocation)")
    print("  Icon:  \(iconLabel)")
    print("  Sound: \(soundLabel)")
    print("")
}

func runDoctor() {
    Logger.info("Running doctor diagnostics")
    printStatusHeader()
    print(header("Diagnostics"))
    print("")

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
        Logger.info("Doctor: all checks passed")
        print(successBold("All checks passed!") + " ClaudeNotifier is properly configured.")
    } else {
        Logger.warning("Doctor: \(issues) issue(s) found")
        print(errorBold("\(issues) issue\(issues == 1 ? "" : "s") found."))
        print("Run '\(info("claude-notifier setup"))' to fix configuration issues.")
        print("Logs: \(hint(Logger.logFilePath.path))")
        exit(1)
    }
}
