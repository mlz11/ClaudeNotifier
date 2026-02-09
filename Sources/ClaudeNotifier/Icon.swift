import Foundation

// MARK: - Icon Variants

enum IconVariant: String, CaseIterable {
    case brown
    case blue
    case green

    static let defaultVariant: IconVariant = .brown

    var filename: String {
        "AppIcon-\(rawValue).icns"
    }

    var displayName: String {
        switch self {
        case .brown: return "brown (default)"
        case .blue: return "blue"
        case .green: return "green"
        }
    }
}

// MARK: - Icon Utilities

func getCurrentVariant() -> IconVariant? {
    guard let appPath = getInstalledAppPath() else { return nil }

    let resourcesPath = appPath.appendingPathComponent("Contents/Resources")
    let currentIconPath = resourcesPath.appendingPathComponent("AppIcon.icns")

    guard FileManager.default.fileExists(atPath: currentIconPath.path) else { return nil }

    // Check which variant matches the current icon by comparing file sizes
    // (A simple heuristic - could be improved with actual file comparison)
    for variant in IconVariant.allCases {
        let variantPath = resourcesPath.appendingPathComponent(variant.filename)
        if FileManager.default.fileExists(atPath: variantPath.path) {
            if filesAreIdentical(currentIconPath, variantPath) {
                return variant
            }
        }
    }

    return nil
}

func filesAreIdentical(_ file1: URL, _ file2: URL) -> Bool {
    guard let data1 = try? Data(contentsOf: file1),
          let data2 = try? Data(contentsOf: file2)
    else {
        return false
    }
    return data1 == data2
}

func setVariant(_ variant: IconVariant) {
    guard let appPath = getInstalledAppPath() else {
        print(error("Error: ClaudeNotifier.app not found"))
        print(warning("Install via 'brew install mlz11/tap/claude-notifier' or 'make install'"))
        exit(1)
    }

    let resourcesPath = appPath.appendingPathComponent("Contents/Resources")
    let variantPath = resourcesPath.appendingPathComponent(variant.filename)
    let targetPath = resourcesPath.appendingPathComponent("AppIcon.icns")

    // Check if variant exists
    guard FileManager.default.fileExists(atPath: variantPath.path) else {
        print(error("Error: Variant icon not found: \(variant.filename)"))
        print("The app may have been built without icon variants.")
        print(warning("Run 'make icons && make install' to regenerate."))
        exit(1)
    }

    // Copy variant to AppIcon.icns
    do {
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: variantPath, to: targetPath)
    } catch let copyError {
        print(error("Error: Failed to copy icon: \(copyError.localizedDescription)"))
        exit(1)
    }

    // Re-codesign the app
    let codesignResult = runProcess("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", appPath.path])
    if codesignResult != 0 {
        print(warning("Warning: Codesigning failed, app may not launch correctly"))
    }

    // Touch the app to update Finder
    _ = runProcess("/usr/bin/touch", [appPath.path])

    Logger.info("Icon changed to: \(variant.rawValue)")
    print(success("Icon changed to: \(variant.rawValue)"))

    // Refresh Notification Center icon cache
    _ = runProcess("/usr/bin/killall", ["NotificationCenter"])
    _ = runProcess("/usr/bin/killall", ["usernoted"])

    print(success("Notification icon updated."))
    print(hint("Finder icon will refresh automatically, or run: killall Finder"))

    // Sync icon choice to config file
    var config = loadConfig()
    config.icon = variant.rawValue
    saveConfig(config)
}

func runProcess(_ path: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return -1
    }
}
