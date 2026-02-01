import AppKit

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

// MARK: - iTerm2 Focus

func focusITermSession(_ sessionId: String) {
    // The session ID from ITERM_SESSION_ID is in format "w0t0p0:UUID"
    // We need the UUID part to match against iTerm2's session id
    let targetId = sessionId.contains(":") ? String(sessionId.split(separator: ":").last ?? "") : sessionId

    guard !targetId.isEmpty else { return }

    let scriptSource = """
    tell application "iTerm2"
        activate
        repeat with w in windows
            tell w
                repeat with t in tabs
                    repeat with s in sessions of t
                        if id of s is "\(targetId)" then
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
