import Foundation

public enum ToneStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case calmConfident
    case friendly
    case direct
    case playful

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .calmConfident: "Calm confident"
        case .friendly: "Friendly"
        case .direct: "Direct"
        case .playful: "Playful"
        }
    }
}

public enum VerbosityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case minimal
    case concise
    case normal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .concise: "Concise"
        case .normal: "Normal"
        }
    }
}

public enum HumorLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case light
    case medium

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .medium: "Medium"
        }
    }
}

public enum WarmthLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

public enum SpokenStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case naturalShort
    case veryShort
    case detailed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .naturalShort: "Natural short"
        case .veryShort: "Very short"
        case .detailed: "Detailed"
        }
    }
}

