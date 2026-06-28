import Foundation

/// Sparkle release channel. Each channel has its own appcast feed so a commit
/// can flow to `dev` fast without ever touching `stable`.
public enum UpdateChannel: String, CaseIterable, Sendable {
    case stable
    case beta
    case dev

    public var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        case .dev: return "Dev"
        }
    }

    /// Override the feed host at build time with the `JarvisUpdateFeedBase`
    /// Info.plist key; otherwise the compiled default is used.
    public static var feedBaseURL: String {
        if let base = Bundle.main.object(forInfoDictionaryKey: "JarvisUpdateFeedBase") as? String,
           !base.isEmpty {
            return base.hasSuffix("/") ? String(base.dropLast()) : base
        }
        return "https://raw.githubusercontent.com/eytanerez/Jarvis/main/Updates"
    }

    public var appcastURLString: String {
        "\(Self.feedBaseURL)/\(rawValue)/appcast.xml"
    }

    public var appcastURL: URL? {
        URL(string: appcastURLString)
    }

    public init?(caseInsensitive raw: String) {
        self.init(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Default channel for a build: dev builds default to `dev`, internal
    /// testers to `beta`, normal users to `stable`. Until more channels exist,
    /// fall back to `beta` for fast iteration.
    public static func defaultChannel(isDeveloperBuild: Bool, isTester: Bool = false) -> UpdateChannel {
        if isDeveloperBuild { return .dev }
        if isTester { return .beta }
        // Only one usable channel exists right now: prefer beta over stable.
        return .beta
    }
}

/// Persists the user's chosen update channel. Defaults follow the build's
/// compiled channel so a dev build starts on `dev`.
public struct UpdateChannelStore {
    public static let defaultsKey = "jarvis.updateChannel"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var compiledDefault: UpdateChannel {
        UpdateChannel(caseInsensitive: JarvisBuildInfo.updateChannel) ?? .beta
    }

    public var current: UpdateChannel {
        get {
            if let raw = defaults.string(forKey: Self.defaultsKey),
               let channel = UpdateChannel(caseInsensitive: raw) {
                return channel
            }
            return compiledDefault
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.defaultsKey)
        }
    }
}
