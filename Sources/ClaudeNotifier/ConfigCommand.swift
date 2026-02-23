import AppKit
import Foundation

// MARK: - Config Command

func runConfigCommand(args: [String]) {
    let subArgs = Array(args.dropFirst(2)) // Drop program name and "config"

    if subArgs.first == "--help" || subArgs.first == "-h" {
        showConfigHelp()
        return
    }

    guard isatty(STDIN_FILENO) != 0 else {
        exitWithError("config command requires an interactive terminal")
    }

    var config = loadConfig()
    let originalTermios = enableRawMode()

    mainMenuLoop(&config)

    // Restore terminal before applying changes (setVariant prints output)
    disableRawMode(originalTermios)

    applyConfig(&config)
}

private func mainMenuLoop(_ config: inout AppConfig) {
    var selectedIndex = 0

    while true {
        let items = [
            MenuItem(label: "Icon color", value: "icon", isCurrent: false),
            MenuItem(label: "Notification sound", value: "sound", isCurrent: false),
            MenuItem(label: "Headless mode notifications", value: "headless", isCurrent: false),
            MenuItem(label: "Done", value: "done", isCurrent: false)
        ]

        guard let choice = renderMenu(
            title: "ClaudeNotifier Configuration",
            items: items,
            selectedIndex: selectedIndex
        ) else {
            return
        }

        switch choice {
        case "icon":
            selectedIndex = 0
            iconSubmenu(&config)
        case "sound":
            selectedIndex = 1
            soundSubmenu(&config)
        case "headless":
            selectedIndex = 2
            headlessSubmenu(&config)
        case "done":
            return
        default:
            break
        }
    }
}

private func iconSubmenu(_ config: inout AppConfig) {
    let currentIcon = config.icon
    let initialIndex = IconVariant.allCases.firstIndex { $0.rawValue == currentIcon } ?? 0

    let items = IconVariant.allCases.map { variant in
        MenuItem(
            label: variant.displayName,
            value: variant.rawValue,
            isCurrent: variant.rawValue == currentIcon
        )
    }

    if let selected = renderMenu(title: "Icon Color", items: items, selectedIndex: initialIndex) {
        config.icon = selected
    }
}

private func soundSubmenu(_ config: inout AppConfig) {
    let currentSound = config.sound
    let initialIndex = systemSounds.firstIndex(of: currentSound) ?? 0

    let items = systemSounds.map { sound in
        MenuItem(
            label: soundDisplayName(sound),
            value: sound,
            isCurrent: sound == currentSound
        )
    }

    if let selected = renderMenu(
        title: "Notification Sound",
        items: items,
        selectedIndex: initialIndex,
        onPreview: { previewSound($0) }
    ) {
        config.sound = selected
    }
}

private func headlessSubmenu(_ config: inout AppConfig) {
    let current = config.notifyInHeadlessMode
    let initialIndex = current ? 0 : 1

    let items = [
        MenuItem(label: "Enabled", value: "true", isCurrent: current),
        MenuItem(label: "Disabled", value: "false", isCurrent: !current)
    ]

    if let selected = renderMenu(
        title: "Headless Mode Notifications",
        items: items,
        selectedIndex: initialIndex
    ) {
        config.notifyInHeadlessMode = (selected == "true")
    }
}

private func previewSound(_ sound: String) {
    switch sound {
    case "none", "default":
        return
    default:
        NSSound(named: NSSound.Name(sound))?.play()
    }
}

private func applyConfig(_ config: inout AppConfig) {
    let oldConfig = loadConfig()

    // Save config first (persists sound change even when icon also changes)
    saveConfig(config)

    // Apply icon change if different
    if config.icon != oldConfig.icon, let variant = IconVariant(rawValue: config.icon) {
        setVariant(variant)
    }
}

func soundDisplayName(_ sound: String) -> String {
    switch sound {
    case "default": return "Default (system sound)"
    case "none": return "None (silent)"
    default: return sound
    }
}

private func showConfigHelp() {
    print("""
    Usage: claude-notifier config

    Open an interactive menu to configure ClaudeNotifier preferences.

    Settings:
      Icon color                    Change the notification icon color (brown, blue, green)
      Notification sound            Choose the notification sound or disable it
      Headless mode notifications   Enable notifications for claude -p sessions (off by default)

    Config file: ~/\(Constants.appSupportDirectory)/\(Constants.configFileName)
    """)
}
