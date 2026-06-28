import Foundation

/// Mirrors the brain `/runtime/version` payload.
public struct BrainVersionReport: Codable, Sendable, Equatable {
    public let appVersion: String
    public let buildNumber: String
    public let gitCommit: String
    public let brainVersion: String
    public let updateChannel: String
    public let buildDate: String

    public init(
        appVersion: String,
        buildNumber: String,
        gitCommit: String,
        brainVersion: String,
        updateChannel: String,
        buildDate: String
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.gitCommit = gitCommit
        self.brainVersion = brainVersion
        self.updateChannel = updateChannel
        self.buildDate = buildDate
    }
}

/// Mirrors the `brain` block of the brain `/runtime/status` payload.
public struct BrainRuntimeReport: Codable, Sendable, Equatable {
    public let brainMode: String
    public let brainPath: String
    public let brainVersion: String
    public let brainGitCommit: String
    public let buildNumber: String?
    public let buildDate: String?
    public let appVersion: String?
    public let matchesAppVersion: Bool?

    public var isDeveloperBrain: Bool { brainMode == "developer" }
}

/// Mirrors the brain `/runtime/status` payload (version + brain + warnings).
public struct RuntimeStatusReport: Codable, Sendable, Equatable {
    public let version: BrainVersionReport
    public let brain: BrainRuntimeReport
    public let warnings: [String]

    public var hasVersionMismatch: Bool { brain.matchesAppVersion == false }
}
