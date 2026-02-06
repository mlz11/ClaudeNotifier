import AppKit

// MARK: - Terminal Colors

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case cyan = "\u{001B}[36m"
}

private let colorsEnabled: Bool = isatty(STDOUT_FILENO) != 0

func colored(_ text: String, _ colors: ANSIColor...) -> String {
    guard colorsEnabled else { return text }
    let codes = colors.map(\.rawValue).joined()
    return "\(codes)\(text)\(ANSIColor.reset.rawValue)"
}

/// Convenience functions for common patterns
func success(_ text: String) -> String {
    colored(text, .green)
}

func error(_ text: String) -> String {
    colored(text, .red)
}

func warning(_ text: String) -> String {
    colored(text, .yellow)
}

func info(_ text: String) -> String {
    colored(text, .cyan)
}

func hint(_ text: String) -> String {
    colored(text, .dim)
}

func header(_ text: String) -> String {
    colored(text, .cyan, .bold)
}

func successBold(_ text: String) -> String {
    colored(text, .green, .bold)
}

func errorBold(_ text: String) -> String {
    colored(text, .red, .bold)
}

// MARK: - App Lifecycle

func exitWithError(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

func terminateApp(afterDelay delay: Double = 0) {
    if delay > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { NSApp.terminate(nil) }
    } else {
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

// MARK: - Terminal Focus

/// Escape a string for safe interpolation into AppleScript string literals.
/// Prevents injection by escaping backslashes and double-quotes.
private func sanitizeForAppleScript(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

enum TerminalType: String, CaseIterable {
    case iterm2
    case terminal
    case unknown

    var displayName: String {
        switch self {
        case .iterm2: return "iTerm2"
        case .terminal: return "Terminal.app"
        case .unknown: return "Unknown"
        }
    }

    var bundleId: String? {
        switch self {
        case .iterm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .unknown: return nil
        }
    }

    /// AppleScript to probe terminal permissions during setup
    var permissionCheckScript: String? {
        switch self {
        case .iterm2:
            return """
            tell application "iTerm2"
                if (count of windows) > 0 then
                    get id of current session of current tab of current window
                end if
            end tell
            """
        case .terminal:
            return """
            tell application "Terminal"
                if (count of windows) > 0 then
                    get tty of selected tab of front window
                end if
            end tell
            """
        case .unknown:
            return nil
        }
    }

    /// All known (non-unknown) terminal types
    static var supported: [TerminalType] {
        allCases.filter { $0 != .unknown }
    }
}

func focusTerminalSession(sessionId: String, terminalType: TerminalType) {
    switch terminalType {
    case .iterm2:
        focusITermSession(sessionId)
    case .terminal:
        focusAppleTerminalSession(sessionId)
    case .unknown:
        break
    }
}

func focusITermSession(_ sessionId: String) {
    // The session ID from ITERM_SESSION_ID is in format "w0t0p0:UUID"
    // We need the UUID part to match against iTerm2's session id
    let targetId = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId

    guard !targetId.isEmpty else { return }

    let safeId = sanitizeForAppleScript(targetId)
    let scriptSource = """
    tell application "iTerm2"
        activate
        repeat with w in windows
            tell w
                repeat with t in tabs
                    repeat with s in sessions of t
                        if id of s is "\(safeId)" then
                            select t
                        end if
                    end repeat
                end repeat
            end tell
        end repeat
    end tell
    """

    if let script = NSAppleScript(source: scriptSource) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}

func focusAppleTerminalSession(_ tty: String) {
    guard !tty.isEmpty else { return }

    let safeTty = sanitizeForAppleScript(tty)
    let scriptSource = """
    tell application "Terminal"
        activate
        repeat with w in windows
            repeat with t in tabs of w
                if tty of t is "\(safeTty)" then
                    set selected tab of w to t
                    set frontmost of w to true
                end if
            end repeat
        end repeat
    end tell
    """

    if let script = NSAppleScript(source: scriptSource) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
