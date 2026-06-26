import Foundation
import JarvisCore

public struct ActiveAppContextReader: Sendable {
    private let capture = TargetAppCapture()

    public init() {}

    public func captureActiveApp() -> ActiveAppSnapshot {
        capture.captureFrontmostApp()
    }
}
