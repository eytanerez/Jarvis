import AppKit
import ApplicationServices
import Foundation
import JarvisCore

public struct AccessibilityReader: Sendable {
    private let maxNodes: Int
    private let maxDepth: Int

    public init(maxNodes: Int = 80, maxDepth: Int = 5) {
        self.maxNodes = maxNodes
        self.maxDepth = maxDepth
    }

    public func readTargetApp(_ target: TargetAppSnapshot?) -> AccessibilityContext {
        guard let target, target.processIdentifier > 0 else {
            return readFrontmostApp()
        }
        return readApp(pid: target.processIdentifier, appName: target.appName, fallbackWindowTitle: target.windowTitle)
    }

    public func readFrontmostApp() -> AccessibilityContext {
        let app = NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else {
            return AccessibilityContext()
        }

        return readApp(pid: pid, appName: app?.localizedName, fallbackWindowTitle: nil)
    }

    private func readApp(pid: pid_t, appName: String?, fallbackWindowTitle: String?) -> AccessibilityContext {
        let appElement = AXUIElementCreateApplication(pid)
        let windowTitle = stringAttribute(kAXTitleAttribute, from: focusedWindow(in: appElement)) ?? fallbackWindowTitle

        var collector = Collector(maxNodes: maxNodes)
        walk(appElement, depth: 0, collector: &collector)

        return AccessibilityContext(
            frontmostApp: appName,
            windowTitle: windowTitle,
            visibleText: collector.texts.joined(separator: "\n").truncated(to: 6000),
            buttons: collector.buttons,
            fields: collector.fields
        )
    }

    private func focusedWindow(in app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value.map { ($0 as! AXUIElement) }
    }

    private func walk(_ element: AXUIElement, depth: Int, collector: inout Collector) {
        guard depth <= maxDepth, collector.count < collector.maxNodes else { return }
        collector.count += 1

        let role = stringAttribute(kAXRoleAttribute, from: element)
        let title = stringAttribute(kAXTitleAttribute, from: element)
        let value = stringAttribute(kAXValueAttribute, from: element)
        let description = stringAttribute(kAXDescriptionAttribute, from: element)

        for text in [title, value, description].compactMap({ $0 }).filter({ !$0.isEmpty }) {
            collector.texts.append(text)
        }

        if role == kAXButtonRole as String, let title, !title.isEmpty {
            collector.buttons.append(title)
        }

        if let role, ["AXTextField", "AXTextArea", "AXSearchField"].contains(role), let value, !value.isEmpty {
            collector.fields.append(value)
        }

        for child in children(of: element) {
            walk(child, depth: depth + 1, collector: &collector)
            if collector.count >= collector.maxNodes {
                break
            }
        }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement?) -> String? {
        guard let element else { return nil }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private struct Collector {
        var count = 0
        let maxNodes: Int
        var texts: [String] = []
        var buttons: [String] = []
        var fields: [String] = []
    }
}

private extension String {
    func truncated(to limit: Int) -> String {
        count > limit ? String(prefix(limit)) : self
    }
}
