import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var notificationConfig: NotificationConfig?

    func applicationDidFinishLaunching(_: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // If we have a notification to show, show it
        if let config = notificationConfig {
            showNotification(
                title: config.title,
                subtitle: config.subtitle,
                body: config.body,
                sessionId: config.sessionId
            )
        } else {
            // Launched without notification config (e.g., from notification click)
            // The delegate method will handle the notification response
            // Give a brief moment for notification response to be delivered, then exit
            terminateApp(afterDelay: 0.5)
        }
    }

    func showNotification(title: String, subtitle: String?, body: String, sessionId: String?) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                if let sub = subtitle {
                    content.subtitle = sub
                }
                content.body = body
                content.sound = .default

                // Store session ID for focus-on-click
                if let sid = sessionId, !sid.isEmpty {
                    content.userInfo = [Constants.sessionIdKey: sid]
                }

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request) { _ in
                    terminateApp()
                }
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
        if let sessionId = response.notification.request.content.userInfo[Constants.sessionIdKey] as? String {
            focusITermSession(sessionId)
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
