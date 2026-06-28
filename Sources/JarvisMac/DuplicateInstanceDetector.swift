import AppKit
import Foundation

/// Detects multiple running copies of Jarvis (same bundle id), which is the
/// usual cause of "which version is running?" confusion — e.g. an old Xcode
/// build plus the installed /Applications copy both alive at once.
@MainActor
public enum DuplicateInstanceDetector {
    public struct Instance: Identifiable {
        public let id: pid_t
        public let path: String
        public let isCurrent: Bool
        public let launchDate: Date?
    }

    public static func runningInstances() -> [Instance] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
        let current = NSRunningApplication.current
        return NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == bundleID }
            .map { app in
                Instance(
                    id: app.processIdentifier,
                    path: app.bundleURL?.path ?? "(unknown)",
                    isCurrent: app.processIdentifier == current.processIdentifier,
                    launchDate: app.launchDate
                )
            }
    }

    public static func hasDuplicates() -> Bool {
        runningInstances().count > 1
    }

    /// Quit every other running Jarvis instance, keeping this one.
    @discardableResult
    public static func quitOtherInstances() -> Int {
        guard let bundleID = Bundle.main.bundleIdentifier else { return 0 }
        let currentPID = NSRunningApplication.current.processIdentifier
        var quit = 0
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier == bundleID && app.processIdentifier != currentPID {
            if app.terminate() { quit += 1 }
        }
        return quit
    }
}
