import AppKit
import Foundation
import JarvisCore

public struct ContextOrchestrator: Sendable {
    private let activeAppReader: ActiveAppContextReader
    private let selectedTextReader: SelectedTextReader
    private let documentReader: DocumentContextReader
    private let browserReader: BrowserReader
    private let accessibilityReader: AccessibilityReader

    public init(
        activeAppReader: ActiveAppContextReader = ActiveAppContextReader(),
        selectedTextReader: SelectedTextReader = SelectedTextReader(),
        documentReader: DocumentContextReader = DocumentContextReader(),
        browserReader: BrowserReader = BrowserReader(),
        accessibilityReader: AccessibilityReader = AccessibilityReader()
    ) {
        self.activeAppReader = activeAppReader
        self.selectedTextReader = selectedTextReader
        self.documentReader = documentReader
        self.browserReader = browserReader
        self.accessibilityReader = accessibilityReader
    }

    public func buildContext(target: TargetAppSnapshot? = nil, settings: ContextSettings = ContextSettings()) -> ContextPack {
        let activeApp = settings.activeAppContextEnabled ? (target ?? activeAppReader.captureActiveApp()) : target
        let selectedSnapshot = settings.selectedTextAccessEnabled
            ? selectedTextReader.readSelectionContext(target: activeApp)
            : SelectedTextSnapshot()

        let browserResult: BrowserReadResult? = settings.browserReaderEnabled
            ? browserReader.readBrowser(target: activeApp)
            : nil
        let browser: BrowserContext?
        let browserError: BrowserReadError?
        switch browserResult {
        case .success(let context):
            browser = context
            browserError = nil
        case .failure(let error):
            browser = nil
            browserError = error
        case nil:
            browser = nil
            browserError = nil
        }

        let accessibility = settings.accessibilityAccessEnabled
            ? accessibilityReader.readTargetApp(activeApp)
            : nil
        let documentResult = documentReader.readDocumentContext(
            target: activeApp,
            selectedText: selectedSnapshot.selectedText ?? browser?.selectedText,
            settings: settings
        )

        var warnings = selectedSnapshot.warnings + documentResult.warnings
        if case .failure(let error)? = browserResult,
           !isExpectedNonBrowserError(error) {
            warnings.append(ContextWarning(code: error.code, message: error.message, source: "browser"))
        }

        let frontmost = activeApp?.appName ?? NSWorkspace.shared.frontmostApplication?.localizedName
        return ContextPacket(
            frontmostApp: frontmost,
            activeApp: activeApp,
            targetApp: activeApp,
            selectedText: selectedSnapshot.selectedText ?? browser?.selectedText ?? documentResult.context?.selectedText,
            surroundingText: selectedSnapshot.surroundingText,
            documentContext: documentResult.context,
            browser: browser,
            browserError: browserError,
            accessibility: accessibility,
            relevantFiles: [],
            relevantMemories: [],
            warnings: warnings,
            screenshotFallbackAvailable: false
        )
    }

    private func isExpectedNonBrowserError(_ error: BrowserReadError) -> Bool {
        if case .notBrowser = error {
            return true
        }
        return false
    }
}
