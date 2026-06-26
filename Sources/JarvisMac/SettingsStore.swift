import Foundation
import JarvisCore

public final class SettingsStore: @unchecked Sendable {
    public let settingsURL: URL

    public init(fileManager: FileManager = .default) {
        let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (base ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("JarvisNotch", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsURL = directory.appendingPathComponent("config.json")
    }

    public func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return AppSettings()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode(AppSettings.self, from: data)) ?? AppSettings()
        let migrated = migrate(decoded)
        if migrated != decoded {
            try? save(migrated)
        }
        return migrated
    }

    public func save(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
    }

    private func migrate(_ settings: AppSettings) -> AppSettings {
        var migrated = settings
        for index in migrated.providers.indices where migrated.providers[index].id == .openAI {
            migrated.providers[index].fastModel = currentOpenAIModel(from: migrated.providers[index].fastModel)
            migrated.providers[index].smartModel = currentOpenAIModel(from: migrated.providers[index].smartModel)
        }
        for index in migrated.providers.indices where migrated.providers[index].id == .gemini {
            migrated.providers[index].fastModel = currentGeminiModel(from: migrated.providers[index].fastModel, fallback: "gemini-3.1-flash-lite")
            migrated.providers[index].smartModel = currentGeminiModel(from: migrated.providers[index].smartModel, fallback: "gemini-3.5-flash")
        }
        migrated.voice.kokoroSpeed = min(max(migrated.voice.kokoroSpeed, 0.5), 1.8)
        let currentVoice = migrated.voice.kokoroVoice.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentVoice.isEmpty || currentVoice == "af_sarah" {
            migrated.voice.kokoroVoice = "af_heart"
        }
        return migrated
    }

    private func currentOpenAIModel(from model: String) -> String {
        switch model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "":
            "gpt-4.1-mini"
        case "gpt-5.5", "gpt-5.4-mini", "gpt-5-nano":
            "gpt-5-mini"
        default:
            model
        }
    }

    private func currentGeminiModel(from model: String, fallback: String) -> String {
        switch model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "":
            fallback
        case "gemini-3.1-flash-light":
            "gemini-3.1-flash-lite"
        case "gemini-2.5-flash-light":
            "gemini-2.5-flash-lite"
        case "gemini-2.0-flash-light":
            "gemini-2.0-flash-lite"
        default:
            model
        }
    }
}
