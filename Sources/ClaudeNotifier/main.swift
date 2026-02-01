import AppKit

// MARK: - Entry Point

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
        sessionId: parsed.sessionId,
        terminalType: parsed.terminalType
    )
}

app.delegate = delegate
app.setActivationPolicy(.accessory) // Run as background app (no dock icon)
app.run()
