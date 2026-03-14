import Foundation

enum Constants {
    // Generated at build time from VERSION file (see Makefile)
    static let version = generatedVersion
    static let defaultTitle = "Claude"
    static let claudeDirectory = ".claude"
    static let appSupportDirectory = "Library/Application Support/ClaudeNotifier"
    static let notifyScriptName = "notify.sh"
    static let settingsFileName = "settings.json"
    static let sessionIdKey = "sessionId"
    static let terminalTypeKey = "terminalType"
    static let logFileName = "claude-notifier.log"
    static let configFileName = "config.json"
    static let bundleIdentifier = "com.mlz11.claude-notifier"
    static let githubLatestReleaseURL = "https://api.github.com/repos/mlz11/ClaudeNotifier/releases/latest"
    static let brewCaskName = "mlz11/tap/claude-notifier"
}
