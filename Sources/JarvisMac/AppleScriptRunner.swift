import AppKit
import Foundation

public struct AppleScriptRunner: Sendable {
    public init() {}

    public func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result.stringValue
    }
}
