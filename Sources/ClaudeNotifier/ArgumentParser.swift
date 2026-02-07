import Foundation

func flagValue(for flags: [String], in args: [String]) -> String? {
    for flag in flags {
        if let index = args.firstIndex(of: flag), index + 1 < args.count {
            let value = args[index + 1]
            if value.hasPrefix("-") {
                fputs("Warning: flag '\(flag)' is missing its value (followed by '\(value)')\n", stderr)
                return nil
            }
            return value
        }
    }
    return nil
}

func parseArguments() -> ParsedArguments {
    let args = CommandLine.arguments

    // Check for subcommands
    if args.count >= 2 {
        switch args[1] {
        case "setup":
            return .command("setup")
        case "doctor":
            return .command("doctor")
        case "icon":
            return .command("icon")
        case "--request-automation":
            // Internal command: request automation permissions (launched via `open`)
            return .command("request-automation")
        case "-h", "--help", "help":
            return .command("help")
        default:
            break
        }
    }

    return ParsedArguments(
        command: nil,
        title: flagValue(for: ["-t", "--title"], in: args) ?? Constants.defaultTitle,
        subtitle: flagValue(for: ["-s", "--subtitle"], in: args),
        body: flagValue(for: ["-m", "--message"], in: args),
        sessionId: flagValue(for: ["-i", "--session-id"], in: args),
        terminalType: flagValue(for: ["-T", "--terminal"], in: args),
        sound: flagValue(for: ["-S", "--sound"], in: args)
    )
}

func showHelp() {
    print("""
    Usage: claude-notifier [command] [options]

    Commands:
      setup                       Set up Claude Code integration (installs hooks)
      doctor                      Diagnose installation and permission issues
      icon [variant]              Change app icon color (brown, blue, green)

    Options:
      -m, --message "text"        The notification body (required for notifications)
      -t, --title "text"          The notification title (default: "Claude")
      -s, --subtitle "text"       The notification subtitle (optional)
      -i, --session-id "id"       Session ID for focus-on-click (optional)
      -T, --terminal "type"       Terminal type: iterm2, terminal (optional)
      -S, --sound "sound"         Notification sound: "default", "none", or a sound name
                                  Examples: Glass, Basso, Blow, Ping, Pop, Funk, Submarine
      -h, --help                  Show this help message
    """)
}
