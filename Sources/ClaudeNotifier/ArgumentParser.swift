import Foundation

func flagValue(for flag: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func parseArguments() -> ParsedArguments {
    let args = CommandLine.arguments

    // Check for subcommands
    if args.count >= 2 {
        switch args[1] {
        case "setup":
            return ParsedArguments(
                command: "setup", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil
            )
        case "-h", "--help", "help":
            return ParsedArguments(
                command: "help", title: "", subtitle: nil, body: nil, sessionId: nil, terminalType: nil
            )
        default:
            break
        }
    }

    return ParsedArguments(
        command: nil,
        title: flagValue(for: "-t", in: args) ?? Constants.defaultTitle,
        subtitle: flagValue(for: "-s", in: args),
        body: flagValue(for: "-m", in: args),
        sessionId: flagValue(for: "-i", in: args),
        terminalType: flagValue(for: "-T", in: args)
    )
}

func showHelp() {
    print("""
    Usage: claude-notifier [command] [options]

    Commands:
      setup           Set up Claude Code integration (installs hooks)

    Options:
      -m "message"    The notification body (required for notifications)
      -t "title"      The notification title (default: "Claude")
      -s "subtitle"   The notification subtitle (optional)
      -i "session"    Session ID for focus-on-click (optional)
      -T "type"       Terminal type: iterm2, terminal (optional)
      -h, --help      Show this help message
    """)
}
