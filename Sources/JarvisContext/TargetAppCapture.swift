import AppKit
import ApplicationServices
import Foundation
import JarvisCore

public struct TargetAppCapture: Sendable {
    public init() {}

    public func captureFrontmostApp() -> TargetAppSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        return TargetAppSnapshot(
            appName: app?.localizedName ?? "Unknown",
            bundleIdentifier: app?.bundleIdentifier,
            processIdentifier: pid,
            windowTitle: windowTitle(for: pid),
            capturedAt: Date()
        )
    }

    private func windowTitle(for pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused)
        guard result == .success, let window = focused else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success else { return nil }
        return title as? String
    }
}
