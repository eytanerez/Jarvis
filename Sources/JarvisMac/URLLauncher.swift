import AppKit
import Foundation

public struct URLLauncher: Sendable {
    public init() {}

    @discardableResult
    public func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    public func openURLs(_ urls: [URL], newWindow: Bool = false) -> Int {
        var opened = 0
        if newWindow, let first = urls.first {
            if openURL(first) {
                opened += 1
            }
            for url in urls.dropFirst() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    _ = NSWorkspace.shared.open(url)
                }
                opened += 1
            }
        } else {
            urls.forEach { url in
                if openURL(url) {
                    opened += 1
                }
            }
        }
        return opened
    }
}
