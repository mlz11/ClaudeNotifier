import Foundation

// MARK: - Logger

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

enum Logger {
    private static let maxLogSize = 500 * 1024 // 500 KB
    private static var initialized = false
    private static var fileHandle: FileHandle?

    static var logFilePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ClaudeNotifier")
            .appendingPathComponent(Constants.logFileName)
    }

    static var logDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ClaudeNotifier")
    }

    // MARK: - Public API

    static func debug(_ message: String) {
        log(message, level: .debug)
    }

    static func info(_ message: String) {
        log(message, level: .info)
    }

    static func warning(_ message: String) {
        log(message, level: .warning)
    }

    static func error(_ message: String) {
        log(message, level: .error)
    }

    // MARK: - Internal

    private static func log(_ message: String, level: LogLevel) {
        ensureInitialized()

        let timestamp = formatTimestamp(Date())
        let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        writeToFile(line)
    }

    private static func ensureInitialized() {
        guard !initialized else { return }
        initialized = true

        let fm = FileManager.default
        let dir = logDirectory

        // Create log directory if needed
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Rotate if needed
        rotate()

        // Open file handle for appending
        let path = logFilePath
        if !fm.fileExists(atPath: path.path) {
            fm.createFile(atPath: path.path, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: path.path)
        fileHandle?.seekToEndOfFile()
    }

    private static func rotate() {
        let path = logFilePath
        let fm = FileManager.default

        guard fm.fileExists(atPath: path.path),
              let attrs = try? fm.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int,
              size > maxLogSize
        else { return }

        let backupPath = path.deletingLastPathComponent()
            .appendingPathComponent(Constants.logFileName + ".1")

        // Remove old backup, rename current to backup
        try? fm.removeItem(at: backupPath)
        try? fm.moveItem(at: path, to: backupPath)
    }

    private static func writeToFile(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        if let handle = fileHandle {
            handle.write(data)
        } else {
            // Fallback to stderr if file handle isn't available
            fputs(line, stderr)
        }
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}
