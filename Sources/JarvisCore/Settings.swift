import Foundation

public enum ProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case anthropic
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        }
    }
}

public struct ProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public var id: ProviderID
    public var enabled: Bool
    public var baseURL: URL?
    public var fastModel: String
    public var smartModel: String

    public init(
        id: ProviderID,
        enabled: Bool,
        baseURL: URL? = nil,
        fastModel: String,
        smartModel: String
    ) {
        self.id = id
        self.enabled = enabled
        self.baseURL = baseURL
        self.fastModel = fastModel
        self.smartModel = smartModel
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case baseURL
        case defaultModel
        case fastModel
        case reasoningModel
        case visionModel
        case smartModel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ProviderID.self, forKey: .id)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        baseURL = try container.decodeIfPresent(URL.self, forKey: .baseURL)
        let defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel)
        fastModel = try container.decodeIfPresent(String.self, forKey: .fastModel) ?? defaultModel ?? ""
        smartModel = try container.decodeIfPresent(String.self, forKey: .smartModel)
            ?? container.decodeIfPresent(String.self, forKey: .reasoningModel)
            ?? defaultModel
            ?? fastModel
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(baseURL, forKey: .baseURL)
        try container.encode(fastModel, forKey: .fastModel)
        try container.encode(smartModel, forKey: .smartModel)
    }
}

public struct ShortcutConfig: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var url: URL

    public init(id: UUID = UUID(), name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

public enum TTSEngine: String, Codable, CaseIterable, Identifiable, Sendable {
    case kokoro
    case chatterbox
    case apple

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .kokoro: "Kokoro"
        case .chatterbox: "Chatterbox"
        case .apple: "Apple"
        }
    }
}

public struct VoiceSettings: Codable, Equatable, Sendable {
    public var ttsEngine: TTSEngine
    public var voiceIdentifier: String?
    public var kokoroVoice: String
    public var kokoroSpeed: Double
    public var chatterboxVoiceReferencePath: String
    public var chatterboxExaggeration: Double
    public var chatterboxCfgWeight: Double
    public var chatterboxStylePreset: String
    public var fallbackToAppleSpeech: Bool
    public var spokenSummaryLimit: Int

    public init(
        ttsEngine: TTSEngine = .kokoro,
        voiceIdentifier: String? = nil,
        kokoroVoice: String = "af_heart",
        kokoroSpeed: Double = 1.0,
        chatterboxVoiceReferencePath: String = "",
        chatterboxExaggeration: Double = 0.45,
        chatterboxCfgWeight: Double = 0.50,
        chatterboxStylePreset: String = "balanced",
        fallbackToAppleSpeech: Bool = true,
        spokenSummaryLimit: Int = 220
    ) {
        self.ttsEngine = ttsEngine
        self.voiceIdentifier = voiceIdentifier
        self.kokoroVoice = kokoroVoice
        self.kokoroSpeed = kokoroSpeed
        self.chatterboxVoiceReferencePath = chatterboxVoiceReferencePath
        self.chatterboxExaggeration = chatterboxExaggeration
        self.chatterboxCfgWeight = chatterboxCfgWeight
        self.chatterboxStylePreset = chatterboxStylePreset
        self.fallbackToAppleSpeech = fallbackToAppleSpeech
        self.spokenSummaryLimit = spokenSummaryLimit
    }

    private enum CodingKeys: String, CodingKey {
        case ttsEngine
        case voiceIdentifier
        case kokoroVoice
        case kokoroSpeed
        case chatterboxVoiceReferencePath
        case chatterboxExaggeration
        case chatterboxCfgWeight
        case chatterboxStylePreset
        case fallbackToAppleSpeech
        case spokenSummaryLimit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ttsEngine = try container.decodeIfPresent(TTSEngine.self, forKey: .ttsEngine) ?? .kokoro
        voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)
        kokoroVoice = try container.decodeIfPresent(String.self, forKey: .kokoroVoice) ?? "af_heart"
        kokoroSpeed = try container.decodeIfPresent(Double.self, forKey: .kokoroSpeed) ?? 1.0
        chatterboxVoiceReferencePath = try container.decodeIfPresent(String.self, forKey: .chatterboxVoiceReferencePath) ?? ""
        chatterboxExaggeration = try container.decodeIfPresent(Double.self, forKey: .chatterboxExaggeration) ?? 0.45
        chatterboxCfgWeight = try container.decodeIfPresent(Double.self, forKey: .chatterboxCfgWeight) ?? 0.50
        chatterboxStylePreset = try container.decodeIfPresent(String.self, forKey: .chatterboxStylePreset) ?? "balanced"
        fallbackToAppleSpeech = try container.decodeIfPresent(Bool.self, forKey: .fallbackToAppleSpeech) ?? true
        spokenSummaryLimit = try container.decodeIfPresent(Int.self, forKey: .spokenSummaryLimit) ?? 220
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ttsEngine, forKey: .ttsEngine)
        try container.encodeIfPresent(voiceIdentifier, forKey: .voiceIdentifier)
        try container.encode(kokoroVoice, forKey: .kokoroVoice)
        try container.encode(kokoroSpeed, forKey: .kokoroSpeed)
        try container.encode(chatterboxVoiceReferencePath, forKey: .chatterboxVoiceReferencePath)
        try container.encode(chatterboxExaggeration, forKey: .chatterboxExaggeration)
        try container.encode(chatterboxCfgWeight, forKey: .chatterboxCfgWeight)
        try container.encode(chatterboxStylePreset, forKey: .chatterboxStylePreset)
        try container.encode(fallbackToAppleSpeech, forKey: .fallbackToAppleSpeech)
        try container.encode(spokenSummaryLimit, forKey: .spokenSummaryLimit)
    }
}

public struct SessionSettings: Codable, Equatable, Sendable {
    public var followUpContextEnabled: Bool
    public var idleTimeoutMinutes: Int

    public init(followUpContextEnabled: Bool = true, idleTimeoutMinutes: Int = 20) {
        self.followUpContextEnabled = followUpContextEnabled
        self.idleTimeoutMinutes = idleTimeoutMinutes
    }
}

public struct MemorySettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var explicitOnly: Bool
    public var paused: Bool
    public var suggestedMemoriesEnabled: Bool

    public init(
        enabled: Bool = true,
        explicitOnly: Bool = true,
        paused: Bool = false,
        suggestedMemoriesEnabled: Bool = false
    ) {
        self.enabled = enabled
        self.explicitOnly = explicitOnly
        self.paused = paused
        self.suggestedMemoriesEnabled = suggestedMemoriesEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case explicitOnly
        case paused
        case suggestedMemoriesEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        explicitOnly = try container.decodeIfPresent(Bool.self, forKey: .explicitOnly) ?? true
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        suggestedMemoriesEnabled = try container.decodeIfPresent(Bool.self, forKey: .suggestedMemoriesEnabled) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(explicitOnly, forKey: .explicitOnly)
        try container.encode(paused, forKey: .paused)
        try container.encode(suggestedMemoriesEnabled, forKey: .suggestedMemoriesEnabled)
    }
}

public enum ContextPrivacyLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case activeAppOnly = 1
    case approvedFolders = 2
    case standardUserFolders = 3
    case sensitiveManualOptIn = 4

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .activeAppOnly: "Active app only"
        case .approvedFolders: "Approved folders"
        case .standardUserFolders: "Desktop, Documents, Downloads"
        case .sensitiveManualOptIn: "Manual sensitive opt-in"
        }
    }
}

public struct ContextSettings: Codable, Equatable, Sendable {
    public var privacyLevel: ContextPrivacyLevel
    public var activeAppContextEnabled: Bool
    public var selectedTextAccessEnabled: Bool
    public var accessibilityAccessEnabled: Bool
    public var browserReaderEnabled: Bool
    public var wordContextEnabled: Bool
    public var fileIndexEnabled: Bool
    public var memoryContextEnabled: Bool
    public var allowCloudFileContents: Bool
    public var localOnlyMode: Bool
    public var approvedFolders: [String]
    public var exclusions: [String]

    public init(
        privacyLevel: ContextPrivacyLevel = .standardUserFolders,
        activeAppContextEnabled: Bool = true,
        selectedTextAccessEnabled: Bool = true,
        accessibilityAccessEnabled: Bool = true,
        browserReaderEnabled: Bool = true,
        wordContextEnabled: Bool = true,
        fileIndexEnabled: Bool = true,
        memoryContextEnabled: Bool = true,
        allowCloudFileContents: Bool = false,
        localOnlyMode: Bool = false,
        approvedFolders: [String] = ContextSettings.defaultApprovedFolders,
        exclusions: [String] = ContextSettings.defaultExclusions
    ) {
        self.privacyLevel = privacyLevel
        self.activeAppContextEnabled = activeAppContextEnabled
        self.selectedTextAccessEnabled = selectedTextAccessEnabled
        self.accessibilityAccessEnabled = accessibilityAccessEnabled
        self.browserReaderEnabled = browserReaderEnabled
        self.wordContextEnabled = wordContextEnabled
        self.fileIndexEnabled = fileIndexEnabled
        self.memoryContextEnabled = memoryContextEnabled
        self.allowCloudFileContents = allowCloudFileContents
        self.localOnlyMode = localOnlyMode
        self.approvedFolders = approvedFolders
        self.exclusions = exclusions
    }

    public static var defaultApprovedFolders: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Desktop", "Documents", "Downloads"].map {
            home.appendingPathComponent($0, isDirectory: true).path
        }
    }

    public static let defaultExclusions: [String] = [
        ".*",
        ".env",
        "*.env",
        "*.pem",
        "*.key",
        "id_rsa",
        "id_ed25519",
        "secrets.*",
        "credentials.*",
        "node_modules",
        ".git",
        "build",
        ".build",
        "DerivedData",
        "__pycache__",
        ".venv",
        "venv"
    ]

    private enum CodingKeys: String, CodingKey {
        case privacyLevel
        case activeAppContextEnabled
        case selectedTextAccessEnabled
        case accessibilityAccessEnabled
        case browserReaderEnabled
        case wordContextEnabled
        case fileIndexEnabled
        case memoryContextEnabled
        case allowCloudFileContents
        case localOnlyMode
        case approvedFolders
        case exclusions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        privacyLevel = try container.decodeIfPresent(ContextPrivacyLevel.self, forKey: .privacyLevel) ?? .standardUserFolders
        activeAppContextEnabled = try container.decodeIfPresent(Bool.self, forKey: .activeAppContextEnabled) ?? true
        selectedTextAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .selectedTextAccessEnabled) ?? true
        accessibilityAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .accessibilityAccessEnabled) ?? true
        browserReaderEnabled = try container.decodeIfPresent(Bool.self, forKey: .browserReaderEnabled) ?? true
        wordContextEnabled = try container.decodeIfPresent(Bool.self, forKey: .wordContextEnabled) ?? true
        fileIndexEnabled = try container.decodeIfPresent(Bool.self, forKey: .fileIndexEnabled) ?? true
        memoryContextEnabled = try container.decodeIfPresent(Bool.self, forKey: .memoryContextEnabled) ?? true
        allowCloudFileContents = try container.decodeIfPresent(Bool.self, forKey: .allowCloudFileContents) ?? false
        localOnlyMode = try container.decodeIfPresent(Bool.self, forKey: .localOnlyMode) ?? false
        approvedFolders = try container.decodeIfPresent([String].self, forKey: .approvedFolders) ?? ContextSettings.defaultApprovedFolders
        exclusions = try container.decodeIfPresent([String].self, forKey: .exclusions) ?? ContextSettings.defaultExclusions
    }
}

public enum WebSearchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case disabled
    case demo
    case realProvider = "real_provider"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .disabled: "Disabled"
        case .demo: "Demo"
        case .realProvider: "Real provider"
        }
    }
}

public struct WebSearchSettings: Codable, Equatable, Sendable {
    public var mode: WebSearchMode

    public init(mode: WebSearchMode = .demo) {
        self.mode = mode
    }
}

public enum PerformanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case performance
    case balanced
    case fullContext = "full_context"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .performance: "Performance"
        case .balanced: "Balanced"
        case .fullContext: "Full Context"
        }
    }

    public var detail: String {
        switch self {
        case .performance:
            "Lightest footprint: no background indexing, no Chatterbox preload, shortest spoken replies, no memory suggestions."
        case .balanced:
            "Everyday default: manual file indexing, Kokoro voice, context captured on Option-Space, Gemini only when needed."
        case .fullContext:
            "Richest context: incremental indexing of approved folders and memory suggestions. Still no system-folder or 30-second reindex loops."
        }
    }
}

public struct PerformanceSettings: Codable, Equatable, Sendable {
    public var mode: PerformanceMode

    public init(mode: PerformanceMode = .balanced) {
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(PerformanceMode.self, forKey: .mode) ?? .balanced
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var providers: [ProviderConfig]
    public var providerFallbackOrder: [ProviderID]
    public var shortcuts: [ShortcutConfig]
    public var voice: VoiceSettings
    public var session: SessionSettings
    public var memory: MemorySettings
    public var context: ContextSettings
    public var webSearch: WebSearchSettings
    public var performance: PerformanceSettings
    public var personality: AssistantPersonality

    public init(
        providers: [ProviderConfig] = AppSettings.defaultProviders,
        providerFallbackOrder: [ProviderID] = [.openAI, .anthropic, .gemini],
        shortcuts: [ShortcutConfig] = AppSettings.defaultShortcuts,
        voice: VoiceSettings = VoiceSettings(),
        session: SessionSettings = SessionSettings(),
        memory: MemorySettings = MemorySettings(),
        context: ContextSettings = ContextSettings(),
        webSearch: WebSearchSettings = WebSearchSettings(),
        performance: PerformanceSettings = PerformanceSettings(),
        personality: AssistantPersonality = .default
    ) {
        self.providers = providers
        self.providerFallbackOrder = providerFallbackOrder
        self.shortcuts = shortcuts
        self.voice = voice
        self.session = session
        self.memory = memory
        self.context = context
        self.webSearch = webSearch
        self.performance = performance
        self.personality = personality
    }

    private enum CodingKeys: String, CodingKey {
        case providers
        case providerFallbackOrder
        case shortcuts
        case voice
        case session
        case memory
        case context
        case webSearch
        case performance
        case personality
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providers = try container.decodeIfPresent([ProviderConfig].self, forKey: .providers) ?? AppSettings.defaultProviders
        providerFallbackOrder = try container.decodeIfPresent([ProviderID].self, forKey: .providerFallbackOrder) ?? [.openAI, .anthropic, .gemini]
        shortcuts = try container.decodeIfPresent([ShortcutConfig].self, forKey: .shortcuts) ?? AppSettings.defaultShortcuts
        voice = try container.decodeIfPresent(VoiceSettings.self, forKey: .voice) ?? VoiceSettings()
        session = try container.decodeIfPresent(SessionSettings.self, forKey: .session) ?? SessionSettings()
        memory = try container.decodeIfPresent(MemorySettings.self, forKey: .memory) ?? MemorySettings()
        context = try container.decodeIfPresent(ContextSettings.self, forKey: .context) ?? ContextSettings()
        webSearch = try container.decodeIfPresent(WebSearchSettings.self, forKey: .webSearch) ?? WebSearchSettings()
        performance = try container.decodeIfPresent(PerformanceSettings.self, forKey: .performance) ?? PerformanceSettings()
        personality = try container.decodeIfPresent(AssistantPersonality.self, forKey: .personality) ?? .default
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providers, forKey: .providers)
        try container.encode(providerFallbackOrder, forKey: .providerFallbackOrder)
        try container.encode(shortcuts, forKey: .shortcuts)
        try container.encode(voice, forKey: .voice)
        try container.encode(session, forKey: .session)
        try container.encode(memory, forKey: .memory)
        try container.encode(context, forKey: .context)
        try container.encode(webSearch, forKey: .webSearch)
        try container.encode(performance, forKey: .performance)
        try container.encode(personality, forKey: .personality)
    }

    public static let defaultProviders: [ProviderConfig] = [
        ProviderConfig(
            id: .openAI,
            enabled: true,
            baseURL: URL(string: "https://api.openai.com/v1"),
            fastModel: "gpt-4.1-mini",
            smartModel: "gpt-5-mini"
        ),
        ProviderConfig(
            id: .anthropic,
            enabled: false,
            baseURL: URL(string: "https://api.anthropic.com"),
            fastModel: "claude-haiku-4-5",
            smartModel: "claude-sonnet-4-5"
        ),
        ProviderConfig(
            id: .gemini,
            enabled: false,
            baseURL: URL(string: "https://generativelanguage.googleapis.com"),
            fastModel: "gemini-2.5-flash-lite",
            smartModel: "gemini-2.5-pro"
        )
    ]

    public static let defaultShortcuts: [ShortcutConfig] = [
        ShortcutConfig(name: "Gmail", url: URL(string: "https://mail.google.com")!),
        ShortcutConfig(name: "Calendar", url: URL(string: "https://calendar.google.com")!),
        ShortcutConfig(name: "Stripe", url: URL(string: "https://dashboard.stripe.com")!)
    ]
}
