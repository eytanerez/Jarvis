import AppKit
import Foundation
import JarvisCore

public typealias BrowserReadResult = Result<BrowserContext, BrowserReadError>

public struct BrowserReader: Sendable {
    private static let pageTextCharacterLimit = 6_000

    public init() {}

    public func readFrontmostBrowser() -> BrowserContext? {
        guard case .success(let context) = readBrowser(target: TargetAppCapture().captureFrontmostApp()) else { return nil }
        return context
    }

    public func readBrowser(target: TargetAppSnapshot?) -> Result<BrowserContext, BrowserReadError> {
        guard let appName = capturedAppName(from: target) else {
            return .failure(.notBrowser(appName: "Unknown app"))
        }

        let kind = browserKind(for: appName, bundleIdentifier: target?.bundleIdentifier)
        if kind == "safari" {
            return runSafariScript(appName: appName)
        }
        if kind == "chromium" {
            return runChromiumScript(appName: appName)
        }
        return .failure(.notBrowser(appName: appName))
    }

    private func runSafariScript(appName: String) -> BrowserReadResult {
        let script = """
        tell application "\(appName)"
          if (count of windows) is 0 then return "__JARVIS_NO_WINDOW__"
          set pageTitle to name of front document
          set pageURL to URL of front document
          set pageText to do JavaScript "\(Self.pageTextJavaScript)" in current tab of front window
          return pageTitle & "\n---JARVIS_URL---\n" & pageURL & "\n---JARVIS_TEXT---\n" & pageText
        end tell
        """
        return parseBrowserOutput(run(script, appName: appName), browser: appName)
    }

    private func runChromiumScript(appName: String) -> BrowserReadResult {
        let script = """
        tell application "\(appName)"
          if (count of windows) is 0 then return "__JARVIS_NO_WINDOW__"
          set activeTab to active tab of front window
          set pageTitle to title of activeTab
          set pageURL to URL of activeTab
          set pageText to execute activeTab javascript "\(Self.pageTextJavaScript)"
          return pageTitle & "\n---JARVIS_URL---\n" & pageURL & "\n---JARVIS_TEXT---\n" & pageText
        end tell
        """
        return parseBrowserOutput(run(script, appName: appName), browser: appName)
    }

    private static var pageTextJavaScript: String {
        """
        (() => { const clone = document.documentElement.cloneNode(true); clone.querySelectorAll('script, style, noscript, svg, canvas, nav, header, footer, aside, form, iframe, [aria-hidden=true], [role=banner], [role=navigation], [role=contentinfo], [hidden]').forEach((node) => node.remove()); const root = clone.querySelector('article, main, [role=main], #content, #main, .article, .post, .entry-content, .content') || clone.querySelector('body') || clone; const text = (window.getSelection && String(window.getSelection()).trim().length > 120) ? String(window.getSelection()) : (root.innerText || root.textContent || ''); return text.replace(/\\s+/g, ' ').trim().slice(0, \(pageTextCharacterLimit)); })()
        """
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func run(_ script: String, appName: String) -> Result<String, BrowserReadError> {
        var errorInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.scriptFailed(browser: appName, message: "Could not create the browser automation script."))
        }
        let descriptor = appleScript.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return .failure(error(from: errorInfo, appName: appName))
        }
        return .success(descriptor.stringValue ?? "")
    }

    private func parseBrowserOutput(_ result: Result<String, BrowserReadError>, browser: String) -> BrowserReadResult {
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            guard !output.isEmpty else {
                return .failure(.emptyPageText(browser: browser, url: nil))
            }
            if output == "__JARVIS_NO_WINDOW__" {
                return .failure(.noBrowserWindow(browser: browser))
            }
            return parseBrowserOutput(output, browser: browser)
        }
    }

    private func parseBrowserOutput(_ output: String, browser: String) -> BrowserReadResult {
        let urlMarker = "\n---JARVIS_URL---\n"
        let textMarker = "\n---JARVIS_TEXT---\n"
        guard let urlRange = output.range(of: urlMarker),
              let textRange = output.range(of: textMarker)
        else {
            return .failure(.scriptFailed(browser: browser, message: "The browser returned page context in an unexpected format."))
        }

        let title = String(output[..<urlRange.lowerBound])
        let urlString = String(output[urlRange.upperBound..<textRange.lowerBound])
        let pageText = String(output[textRange.upperBound...])
        guard !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyPageText(browser: browser, url: urlString.isEmpty ? nil : urlString))
        }

        return .success(
            BrowserContext(
                browser: browser,
                title: title,
                url: URL(string: urlString),
                selectedText: SelectedTextReader().readSelectedText(),
                pageText: pageText
            )
        )
    }

    private func error(from errorInfo: NSDictionary, appName: String) -> BrowserReadError {
        let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Browser automation failed."
        let lower = message.lowercased()
        if number == -1743 || lower.contains("not authorized") || lower.contains("not authorised") || lower.contains("not allowed") {
            return .automationPermissionDenied(appName: appName)
        }
        if lower.contains("javascript") || lower.contains("java script") {
            return .javascriptFromAppleEventsDisabled(browser: appName)
        }
        return .scriptFailed(browser: appName, message: message)
    }

    private func capturedAppName(from target: TargetAppSnapshot?) -> String? {
        let targetName = target?.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetName, !targetName.isEmpty, targetName != "Unknown" {
            return targetName
        }
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    private func browserKind(for appName: String, bundleIdentifier: String?) -> String? {
        let lower = "\(appName) \(bundleIdentifier ?? "")".lowercased()
        if lower.contains("safari") {
            return "safari"
        }
        if lower.contains("chrome") || lower.contains("arc") || lower.contains("chromium") || lower.contains("edge") {
            return "chromium"
        }
        return nil
    }
}
