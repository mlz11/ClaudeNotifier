import AppKit

// MARK: - Entry Point

let parsed = parseArguments()

switch parsed.command {
case "setup":
    runSetup()
    exit(0)
case "doctor":
    runDoctor()
    exit(0)
case "icon":
    runIconCommand(args: CommandLine.arguments)
    exit(0)
case "request-automation":
    requestTerminalPermissions()
    exit(0)
case "version":
    print("ClaudeNotifier \(Constants.version)")
    exit(0)
case "help":
    showHelp()
    exit(0)
default:
    break
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
        terminalType: parsed.terminalType,
        sound: parsed.sound
    )
}

app.delegate = delegate
app.setActivationPolicy(.accessory) // Run as background app (no dock icon)
app.run()
