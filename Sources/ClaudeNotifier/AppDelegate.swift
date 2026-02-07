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

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
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

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request) { _ in
                    terminateApp()
                }
                // Safety net: terminate even if completion handler never fires
                terminateApp(afterDelay: 10.0)
            } else {
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
        if let sessionId = userInfo[Constants.sessionIdKey] as? String {
            let terminalTypeStr = userInfo[Constants.terminalTypeKey] as? String ?? ""
            let terminalType = TerminalType(rawValue: terminalTypeStr) ?? .unknown
            focusTerminalSession(sessionId: sessionId, terminalType: terminalType)
        }
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
