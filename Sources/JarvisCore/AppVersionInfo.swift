import Foundation

/// The single in-app source of truth for "what is running". Bundle values win
/// at runtime (they reflect the actual installed build), with the generated
/// `JarvisBuildInfo` as the fallback for git commit / brain version / date that
/// the bundle does not carry.
public struct AppVersionInfo: Sendable, Equatable {
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

    public static var current: AppVersionInfo {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let channel = UpdateChannelStore().current.rawValue
        return AppVersionInfo(
            appVersion: shortVersion?.nonEmpty ?? JarvisBuildInfo.appVersion,
            buildNumber: bundleVersion?.nonEmpty ?? JarvisBuildInfo.buildNumber,
            gitCommit: JarvisBuildInfo.gitCommit,
            brainVersion: JarvisBuildInfo.brainVersion,
            updateChannel: channel,
            buildDate: JarvisBuildInfo.buildDate
        )
    }

    /// Environment passed to the Python brain so it reports the real running
    /// build, not just its own compiled constants.
    public var brainEnvironment: [String: String] {
        [
            "JARVIS_APP_VERSION": appVersion,
            "JARVIS_APP_BUILD": buildNumber,
            "JARVIS_APP_COMMIT": gitCommit,
            "JARVIS_APP_CHANNEL": updateChannel,
        ]
    }

    public func dictionary() -> [String: String] {
        [
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "gitCommit": gitCommit,
            "brainVersion": brainVersion,
            "updateChannel": updateChannel,
            "buildDate": buildDate,
        ]
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
