import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var notificationConfig: NotificationConfig?

    /// Convert sound name string to UNNotificationSound
    private func notificationSound(from soundName: String?) -> UNNotificationSound? {
        guard let name = soundName else { return .default }
        switch name.lowercased() {
        case "default":
            return .default
        case "none", "":
            return nil
        default:
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // If we have a notification to show, show it
        if let config = notificationConfig {
            showNotification(config)
        } else {
            // Launched without notification config (e.g., from notification click)
            // The delegate method will handle the notification response
            // Give a brief moment for notification response to be delivered, then exit
            terminateApp(afterDelay: 0.5)
        }
    }

    /// Clean a user message for use as subtitle: strip pasted-text markers, take first line, truncate
    private func cleanMessageForSubtitle(_ message: String) -> String? {
        var cleaned = message
        let pastedPattern = "\\[Pasted text #\\d+ [^\\]]*\\]"
        if let regex = try? NSRegularExpression(pattern: pastedPattern) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let firstLine = cleaned.components(separatedBy: .newlines).first ?? ""
        guard !firstLine.isEmpty else { return nil }
        return firstLine.count > 40 ? String(firstLine.prefix(40)) + "..." : firstLine
    }

    /// Resolve session context (conversation name or first message) from Claude history
    private func resolveSessionContext(sessionId: String) -> String? {
        let historyPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(Constants.claudeDirectory)
            .appendingPathComponent("history.jsonl")

        guard let data = try? Data(contentsOf: historyPath),
              let content = String(data: data, encoding: .utf8)
        else {
            Logger.debug("Could not read history.jsonl")
            return nil
        }

        var rename: String?
        var firstMessage: String?

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let lineSessionId = json["sessionId"] as? String,
                  lineSessionId == sessionId
            else { continue }

            guard let messageType = json["type"] as? String, messageType == "user",
                  let message = json["message"] as? String
            else { continue }

            if message.hasPrefix("/rename ") {
                rename = String(message.dropFirst("/rename ".count)).trimmingCharacters(in: .whitespaces)
            } else if firstMessage == nil, !message.hasPrefix("/") {
                firstMessage = cleanMessageForSubtitle(message)
            }
        }

        return rename ?? firstMessage
    }

    func showNotification(_ config: NotificationConfig) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.error("Notification authorization error: \(error.localizedDescription)")
            }
            if granted {
                Logger.info("Notification authorization granted")
                let content = UNMutableNotificationContent()
                content.title = config.title

                // Resolve subtitle: use session context if configured
                var resolvedSubtitle = config.subtitle
                let appConfig = loadConfig()
                let useSession = appConfig.subtitleContent == "session"
                if useSession, let claudeSessionId = config.claudeSessionId, !claudeSessionId.isEmpty {
                    if let sessionContext = self.resolveSessionContext(sessionId: claudeSessionId) {
                        Logger.debug("Resolved session context: \(sessionContext)")
                        resolvedSubtitle = sessionContext
                    }
                }

                if let subtitle = resolvedSubtitle {
                    content.subtitle = subtitle
                    content.threadIdentifier = subtitle
                }
                content.body = config.body
                content.sound = self.notificationSound(from: config.sound)

                // Store session ID and terminal type for focus-on-click
                var userInfo: [String: String] = [:]
                if let sessionId = config.sessionId, !sessionId.isEmpty {
                    userInfo[Constants.sessionIdKey] = sessionId
                }
                if let terminalType = config.terminalType, !terminalType.isEmpty {
                    userInfo[Constants.terminalTypeKey] = terminalType
                }
                if !userInfo.isEmpty {
                    content.userInfo = userInfo
                }

                // Deterministic ID from source + project so a new notification
                // replaces the previous one per terminal tab per project
                let notificationId =
                    "claude-\(config.terminalType ?? "")-\(config.sessionId ?? "")-\(resolvedSubtitle ?? "")"

                let request = UNNotificationRequest(
                    identifier: notificationId,
                    content: content,
                    trigger: nil
                )
                center.add(request) { addError in
                    if let addError = addError {
                        Logger.error("Failed to deliver notification: \(addError.localizedDescription)")
                    } else {
                        Logger.info("Notification delivered")
                    }
                    terminateApp()
                }
                // Safety net: terminate even if completion handler never fires
                terminateApp(afterDelay: 10.0)
            } else {
                Logger.warning("Notification permission denied")
                fputs("Notification permission denied\n", stderr)
                terminateApp()
            }
        }
    }

    /// Called when user clicks on notification
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let terminalTypeStr = userInfo[Constants.terminalTypeKey] as? String ?? ""
        let terminalType = TerminalType(rawValue: terminalTypeStr) ?? .unknown
        let sessionId = userInfo[Constants.sessionIdKey] as? String ?? ""
        Logger
            .info(
                "Notification clicked: terminal=\(terminalType.displayName), sessionId=\(sessionId.isEmpty ? "none" : sessionId)"
            )
        focusTerminalSession(sessionId: sessionId, terminalType: terminalType)
        completionHandler()
        terminateApp()
    }

    /// Allow notifications to show even when app is in foreground
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
