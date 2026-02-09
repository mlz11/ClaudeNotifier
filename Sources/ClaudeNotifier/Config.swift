import Foundation

// MARK: - App Configuration

struct AppConfig: Codable {
    var icon: String
    var sound: String

    static let defaultConfig = AppConfig(icon: "brown", sound: "default")
}

let systemSounds = [
    "default", "none",
    "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
    "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
]

func configFilePath() -> URL {
    appSupportDirectory().appendingPathComponent(Constants.configFileName)
}

func loadConfig() -> AppConfig {
    let path = configFilePath()

    guard FileManager.default.fileExists(atPath: path.path) else {
        return .defaultConfig
    }

    do {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    } catch {
        Logger.warning("Failed to load config: \(error.localizedDescription)")
        return .defaultConfig
    }
}

func saveConfig(_ config: AppConfig) {
    let dir = appSupportDirectory()
    let path = dir.appendingPathComponent(Constants.configFileName)

    // Ensure directory exists
    if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: path, options: .atomic)
        Logger.info("Saved config to \(path.path)")
    } catch {
        Logger.error("Failed to save config: \(error.localizedDescription)")
        fputs("Error saving config: \(error.localizedDescription)\n", stderr)
    }
}
