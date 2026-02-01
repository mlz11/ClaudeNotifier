import Foundation

struct NotificationConfig {
    let title: String
    let subtitle: String?
    let body: String
    let sessionId: String?
    let terminalType: String?
}

struct ParsedArguments {
    let command: String?
    let title: String
    let subtitle: String?
    let body: String?
    let sessionId: String?
    let terminalType: String?
}
