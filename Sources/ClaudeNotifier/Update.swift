import Foundation

// MARK: - Version Comparison

func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let partsA = lhs.split(separator: ".").compactMap { Int($0) }
    let partsB = rhs.split(separator: ".").compactMap { Int($0) }
    let count = max(partsA.count, partsB.count)

    for i in 0 ..< count {
        let valA = i < partsA.count ? partsA[i] : 0
        let valB = i < partsB.count ? partsB[i] : 0
        if valA < valB { return .orderedAscending }
        if valA > valB { return .orderedDescending }
    }
    return .orderedSame
}

// MARK: - GitHub API

func fetchLatestVersion() -> (tag: String, version: String)? {
    guard let url = URL(string: Constants.githubLatestReleaseURL) else { return nil }

    var request = URLRequest(url: url)
    request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 10

    let semaphore = DispatchSemaphore(value: 0)
    var result: (tag: String, version: String)?

    URLSession.shared.dataTask(with: request) { data, _, _ in
        defer { semaphore.signal() }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String
        else { return }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        result = (tag: tagName, version: version)
    }.resume()

    semaphore.wait()
    return result
}

// MARK: - Brew Detection

func isBrewInstall() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    // The cask token is "claude-notifier" (without tap prefix).
    // brew list --cask resolves by token, not by full tap-qualified name.
    process.arguments = ["brew", "list", "--cask", "claude-notifier"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

func isBrewAvailable() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["brew", "--version"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

// MARK: - Update Command

// NOTE: fetchLatestVersion() uses DispatchSemaphore to block synchronously.
// This is safe in CLI mode but would deadlock on the main thread of an NSApplication run loop.
// The update and doctor commands call exit() before reaching app.run(), so this is fine.

func runUpdate() {
    Logger.info("Running update check")
    print("Checking for updates...\(hint(" (this may take a moment)"))")

    guard let latest = fetchLatestVersion() else {
        print(error("Could not check for updates (network error or GitHub API unavailable)."))
        exit(1)
    }

    let current = Constants.version
    Logger.info("Current: \(current), Latest: \(latest.version)")

    if compareVersions(current, latest.version) != .orderedAscending {
        print(success("Already up to date") + " (v\(current))")
        return
    }

    print("Update available: \(info("v\(current)")) → \(info("v\(latest.version)"))")

    guard isBrewAvailable() else {
        print(error("Homebrew is not installed."))
        print("Install the update manually:")
        print(
            "  \(info("curl -fsSL https://raw.githubusercontent.com/mlz11/ClaudeNotifier/main/Scripts/install.sh | bash"))"
        )
        exit(1)
    }

    guard isBrewInstall() else {
        print(warning("ClaudeNotifier was not installed via Homebrew."))
        print("Reinstall via Homebrew to enable automatic updates:")
        print("  \(info("brew install --cask \(Constants.brewCaskName)"))")
        exit(1)
    }

    print("Upgrading via Homebrew...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["brew", "upgrade", "--cask", "claude-notifier"]
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            Logger.info("Update completed successfully")
            print(success("Updated successfully!"))
        } else {
            Logger.error("Upgrade failed with exit code \(process.terminationStatus)")
            print(error("Upgrade failed (exit code \(process.terminationStatus))."))
            exit(1)
        }
    } catch let brewError {
        Logger.error("Failed to run brew: \(brewError.localizedDescription)")
        print(error("Failed to run brew: \(brewError.localizedDescription)"))
        exit(1)
    }
}

// MARK: - Doctor Integration

func checkVersionUpToDate() -> CheckResult {
    guard let latest = fetchLatestVersion() else {
        return CheckResult(
            passed: false,
            message: "Version: v\(Constants.version) (could not check for updates)",
            remediation: "Check your network connection or try again later"
        )
    }

    let current = Constants.version
    if compareVersions(current, latest.version) != .orderedAscending {
        return CheckResult(passed: true, message: "Version: v\(current) (latest)")
    }

    return CheckResult(
        passed: false,
        message: "Version: v\(current) (v\(latest.version) available)",
        remediation: "Run 'claude-notifier update' to upgrade"
    )
}
