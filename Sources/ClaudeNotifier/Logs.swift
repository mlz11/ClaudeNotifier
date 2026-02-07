import Foundation

// MARK: - Logs Command

func runLogsCommand(args: [String]) {
    let subArgs = Array(args.dropFirst(2)) // Drop program name and "logs"

    if subArgs.first == "--clear" || subArgs.first == "-c" {
        clearLogs()
        return
    }

    if subArgs.first == "--help" || subArgs.first == "-h" {
        showLogsHelp()
        return
    }

    printLogs()
}

private func printLogs() {
    let path = Logger.logFilePath

    guard FileManager.default.fileExists(atPath: path.path) else {
        print("No log file found at \(path.path)")
        return
    }

    do {
        let contents = try String(contentsOf: path, encoding: .utf8)
        if contents.isEmpty {
            print("Log file is empty.")
        } else {
            print(contents, terminator: "")
        }
    } catch {
        fputs("Error reading log file: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

private func clearLogs() {
    let path = Logger.logFilePath

    guard FileManager.default.fileExists(atPath: path.path) else {
        print("No log file to clear.")
        return
    }

    do {
        try "".write(to: path, atomically: true, encoding: .utf8)
        print("Log file cleared.")
    } catch {
        fputs("Error clearing log file: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

private func showLogsHelp() {
    print("""
    Usage: claude-notifier logs [option]

    View or manage the log file.

    Options:
      --clear, -c    Clear the log file
      --help, -h     Show this help

    Log file location: \(Logger.logFilePath.path)
    """)
}
