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
                if let subtitle = config.subtitle {
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
                    "claude-\(config.terminalType ?? "")-\(config.sessionId ?? "")-\(config.subtitle ?? "")"

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
