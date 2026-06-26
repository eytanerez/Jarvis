import AppKit
import Foundation
import JarvisCore

public struct ContextBuilder: Sendable {
    private let orchestrator: ContextOrchestrator

    public init(orchestrator: ContextOrchestrator = ContextOrchestrator()) {
        self.orchestrator = orchestrator
    }

    public func buildContext(target: TargetAppSnapshot? = nil, settings: ContextSettings = ContextSettings()) -> ContextPacket {
        orchestrator.buildContext(target: target, settings: settings)
    }
}
