import Foundation

func flagValue(for flags: [String], in args: [String]) -> String? {
    for flag in flags {
        if let index = args.firstIndex(of: flag), index + 1 < args.count {
            return args[index + 1]
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
            return ParsedArguments(
                command: "setup", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil, sound: nil
            )
        case "doctor":
            return ParsedArguments(
                command: "doctor", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil, sound: nil
            )
        case "--request-automation":
            // Internal command: request automation permissions (launched via `open`)
            return ParsedArguments(
                command: "request-automation", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil,
                sound: nil
            )
        case "--check-automation":
            // Internal command: check automation permissions in isolated process (for doctor)
            return ParsedArguments(
                command: "check-automation", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil,
                sound: nil
            )
        case "-h", "--help", "help":
            return ParsedArguments(
                command: "help", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil, sound: nil
            )
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
