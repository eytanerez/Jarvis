import AppKit
import ApplicationServices
import Foundation
import JarvisCore

public struct SelectedTextSnapshot: Equatable, Sendable {
    public var selectedText: String?
    public var surroundingText: String?
    public var warnings: [ContextWarning]

    public init(selectedText: String? = nil, surroundingText: String? = nil, warnings: [ContextWarning] = []) {
        self.selectedText = selectedText
        self.surroundingText = surroundingText
        self.warnings = warnings
    }
}

public struct SelectedTextReader: Sendable {
    public init() {}

    public func readSelectionContext(target: TargetAppSnapshot? = nil) -> SelectedTextSnapshot {
        if let target,
           target.processIdentifier > 0,
           let element = focusedElement(in: AXUIElementCreateApplication(target.processIdentifier)) {
            return SelectedTextSnapshot(
                selectedText: selectedText(in: element),
                surroundingText: surroundingText(in: element)
            )
        }

        guard let element = systemFocusedElement() else {
            return SelectedTextSnapshot()
        }
        return SelectedTextSnapshot(
            selectedText: selectedText(in: element),
            surroundingText: surroundingText(in: element)
        )
    }

    public func readSelectedText(target: TargetAppSnapshot? = nil) -> String? {
        readSelectionContext(target: target).selectedText
    }

    public func readSelectedText() -> String? {
        readSelectedText(target: nil)
    }

    private func systemFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let focused else { return nil }
        return (focused as! AXUIElement)
    }

    private func focusedElement(in app: AXUIElement) -> AXUIElement? {
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused)
        if focusedResult == .success, let focused {
            return (focused as! AXUIElement)
        }

        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard windowResult == .success, let focusedWindow else { return nil }
        return firstTextElement(in: (focusedWindow as! AXUIElement), depth: 0)
    }

    private func selectedText(in element: AXUIElement) -> String? {
        var selected: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected)
        guard selectedResult == .success, let text = selected as? String, !text.isEmpty else {
            return nil
        }

        return text
    }

    private func surroundingText(in element: AXUIElement) -> String? {
        guard let value = stringAttribute(kAXValueAttribute, from: element) else {
            return nil
        }
        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return normalized.truncated(to: 4_000)
    }

    private func firstTextElement(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth <= 4 else { return nil }
        let role = stringAttribute(kAXRoleAttribute, from: element)
        if let role, ["AXTextField", "AXTextArea", "AXStaticText"].contains(role) {
            return element
        }
        var childrenValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        guard result == .success, let children = childrenValue as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let match = firstTextElement(in: child, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
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
}

private extension String {
    func truncated(to limit: Int) -> String {
        count > limit ? String(prefix(limit)) : self
    }
}
