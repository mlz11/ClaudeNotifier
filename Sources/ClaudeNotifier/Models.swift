import Foundation

struct NotificationConfig {
    let title: String
    let subtitle: String?
    let body: String
    let sessionId: String?
    let terminalType: String?
    let sound: String?
}

struct ParsedArguments {
    let command: String?
    let title: String
    let subtitle: String?
    let body: String?
    let sessionId: String?
    let terminalType: String?
    let sound: String?

    static func command(_ name: String) -> ParsedArguments {
        ParsedArguments(
            command: name,
            title: "",
            subtitle: nil,
            body: nil,
            sessionId: nil,
            terminalType: nil,
            sound: nil
        )
    }
}
