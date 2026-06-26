import Foundation

public enum AssistantMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case neutral
    case quick
    case focused
    case playful
    case careful
    case confused
    case serious
    case excited

    public var id: String { rawValue }
}

public enum PauseStyle: String, Codable, Sendable {
    case clipped
    case natural
    case deliberate
}

public struct VoiceStyle: Codable, Equatable, Sendable {
    public var mood: AssistantMood
    public var speed: Double
    public var pauseStyle: PauseStyle
    public var maxSpokenLength: Int
    public var allowMicroReaction: Bool
    public var ttsVoice: String?
    public var exaggeration: Double
    public var cfgWeight: Double

    public init(
        mood: AssistantMood = .neutral,
        speed: Double = 1.0,
        pauseStyle: PauseStyle = .natural,
        maxSpokenLength: Int = 220,
        allowMicroReaction: Bool = false,
        ttsVoice: String? = nil,
        exaggeration: Double = 0.45,
        cfgWeight: Double = 0.50
    ) {
        self.mood = mood
        self.speed = speed
        self.pauseStyle = pauseStyle
        self.maxSpokenLength = maxSpokenLength
        self.allowMicroReaction = allowMicroReaction
        self.ttsVoice = ttsVoice
        self.exaggeration = exaggeration
        self.cfgWeight = cfgWeight
    }

    public static func style(for mood: AssistantMood, spokenLimit: Int) -> VoiceStyle {
        switch mood {
        case .quick:
            VoiceStyle(mood: mood, speed: 1.08, pauseStyle: .clipped, maxSpokenLength: min(spokenLimit, 150), exaggeration: 0.32, cfgWeight: 0.52)
        case .focused:
            VoiceStyle(mood: mood, speed: 1.0, pauseStyle: .natural, maxSpokenLength: spokenLimit, allowMicroReaction: true, exaggeration: 0.45, cfgWeight: 0.50)
        case .playful:
            VoiceStyle(mood: mood, speed: 1.03, pauseStyle: .natural, maxSpokenLength: min(spokenLimit, 180), allowMicroReaction: true, exaggeration: 0.58, cfgWeight: 0.45)
        case .careful:
            VoiceStyle(mood: mood, speed: 0.92, pauseStyle: .deliberate, maxSpokenLength: spokenLimit, exaggeration: 0.34, cfgWeight: 0.56)
        case .confused:
            VoiceStyle(mood: mood, speed: 0.94, pauseStyle: .deliberate, maxSpokenLength: spokenLimit, exaggeration: 0.38, cfgWeight: 0.58)
        case .serious:
            VoiceStyle(mood: mood, speed: 0.90, pauseStyle: .deliberate, maxSpokenLength: min(spokenLimit, 180), exaggeration: 0.30, cfgWeight: 0.62)
        case .excited:
            VoiceStyle(mood: mood, speed: 1.06, pauseStyle: .natural, maxSpokenLength: min(spokenLimit, 180), allowMicroReaction: true, exaggeration: 0.70, cfgWeight: 0.42)
        case .neutral:
            VoiceStyle(mood: mood, speed: 1.0, pauseStyle: .natural, maxSpokenLength: spokenLimit, exaggeration: 0.45, cfgWeight: 0.50)
        }
    }
}

public struct AssistantPersonality: Codable, Equatable, Sendable {
    public var name: String
    public var tone: ToneStyle
    public var verbosity: VerbosityLevel
    public var humor: HumorLevel
    public var warmth: WarmthLevel
    public var spokenStyle: SpokenStyle
    public var variedCommandResponses: Bool

    public init(
        name: String = "Jarvis",
        tone: ToneStyle = .calmConfident,
        verbosity: VerbosityLevel = .concise,
        humor: HumorLevel = .light,
        warmth: WarmthLevel = .medium,
        spokenStyle: SpokenStyle = .naturalShort,
        variedCommandResponses: Bool = true
    ) {
        self.name = name
        self.tone = tone
        self.verbosity = verbosity
        self.humor = humor
        self.warmth = warmth
        self.spokenStyle = spokenStyle
        self.variedCommandResponses = variedCommandResponses
    }

    public static let `default` = AssistantPersonality()
}

