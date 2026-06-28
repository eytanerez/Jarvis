import AppKit
import Foundation

/// Where the running Jarvis.app actually lives. Used to warn when Jarvis is run
/// from a development or temporary location where Sparkle updates won't behave.
public struct InstallLocation: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case applications          // /Applications/Jarvis.app  (the good one)
        case userApplications      // ~/Applications/Jarvis.app
        case mountedDMG            // /Volumes/... (running from a mounted image)
        case translocated          // Gatekeeper App Translocation random path
        case derivedData           // Xcode DerivedData
        case repoBuild             // repo .build output
        case downloads
        case desktop
        case other

        public var isProperlyInstalled: Bool { self == .applications }
    }

    public let path: String
    public let kind: Kind

    public var isProperlyInstalled: Bool { kind.isProperlyInstalled }

    /// True when updates may misbehave (mounted image / translocated copy).
    public var blocksUpdates: Bool { kind == .mountedDMG || kind == .translocated }

    public static var current: InstallLocation {
        let url = Bundle.main.bundleURL
        return InstallLocation(path: url.path, kind: classify(url.path))
    }

    static func classify(_ rawPath: String) -> Kind {
        let path = rawPath
        if path.contains("/AppTranslocation/") { return .translocated }
        if path.hasPrefix("/Volumes/") { return .mountedDMG }
        if path.contains("/DerivedData/") { return .derivedData }
        if path.contains("/.build/") { return .repoBuild }
        if path.hasPrefix("/Applications/") { return .applications }
        let home = NSHomeDirectory()
        if path.hasPrefix("\(home)/Applications/") { return .userApplications }
        if path.hasPrefix("\(home)/Downloads/") || path.contains("/Downloads/") { return .downloads }
        if path.hasPrefix("\(home)/Desktop/") || path.contains("/Desktop/") { return .desktop }
        return .other
    }

    /// Non-blocking warning to surface in Settings / Debug, or nil when fine.
    public var warningMessage: String? {
        if isProperlyInstalled { return nil }
        if blocksUpdates {
            return """
            Jarvis is running from a mounted disk image:
            \(path)

            Drag Jarvis into /Applications and launch it from there to receive updates.
            """
        }
        return """
        You are running Jarvis from a development or temporary location:
        \(path)

        Install Jarvis into /Applications to receive normal updates.
        """
    }

    public static var applicationsDestination: URL {
        URL(fileURLWithPath: "/Applications/Jarvis.app")
    }
}

/// Copies the running app into /Applications and relaunches it from there.
public enum InstallLocationMover {
    public enum MoveError: Error, CustomStringConvertible {
        case alreadyInstalled
        case copyFailed(String)
        case notWritable

        public var description: String {
            switch self {
            case .alreadyInstalled: return "Jarvis is already in /Applications."
            case .copyFailed(let detail): return "Could not copy Jarvis to /Applications: \(detail)"
            case .notWritable: return "/Applications is not writable."
            }
        }
    }

    /// Copy the current bundle to /Applications/Jarvis.app, replacing any
    /// existing copy. Returns the destination URL on success.
    @discardableResult
    public static func copyToApplications() throws -> URL {
        let source = Bundle.main.bundleURL
        let destination = InstallLocation.applicationsDestination
        if source.standardizedFileURL == destination.standardizedFileURL {
            throw MoveError.alreadyInstalled
        }
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw MoveError.copyFailed(error.localizedDescription)
        }
        return destination
    }

    /// Copy to /Applications and relaunch from there, then quit this instance.
    @MainActor
    public static func moveToApplicationsAndRelaunch() throws {
        let destination = try copyToApplications()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
