import Foundation
import UserNotifications

let semaphore = DispatchSemaphore(value: 0)

func showNotification(title: String, subtitle: String?, body: String) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            let content = UNMutableNotificationContent()
            content.title = title
            if let sub = subtitle {
                content.subtitle = sub
            }
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { error in
                if let error = error {
                    fputs("Error: \(error.localizedDescription)\n", stderr)
                }
                semaphore.signal()
            }
        } else {
            fputs("Notification permission denied\n", stderr)
            semaphore.signal()
        }
    }
}

// Parse arguments
var title = "Claude"
var subtitle: String? = nil
var body = "Hello!"

var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]
    if arg == "-t" && i + 1 < CommandLine.arguments.count {
        title = CommandLine.arguments[i + 1]
        i += 2
    } else if arg == "-s" && i + 1 < CommandLine.arguments.count {
        subtitle = CommandLine.arguments[i + 1]
        i += 2
    } else if arg == "-m" && i + 1 < CommandLine.arguments.count {
        body = CommandLine.arguments[i + 1]
        i += 2
    } else {
        i += 1
    }
}

showNotification(title: title, subtitle: subtitle, body: body)
semaphore.wait()
exit(0)
