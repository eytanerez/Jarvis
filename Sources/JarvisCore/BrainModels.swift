import Foundation

public struct BrainChatRequest: Codable, Equatable, Sendable {
    public var message: String
    public var conversationId: String
    public var context: ContextPacket?
    public var session: SessionStore
    public var mode: String
    /// Intent decided on the Swift side (single source of truth). The brain
    /// honors this instead of re-deriving its own copy of the keyword tables.
    public var intent: String?
    /// Whether the request needs on-screen/browser context, computed once from
    /// `IntentRouter.screenContextPhrases` so the brain doesn't keep a second copy.
    public var requiresScreenContext: Bool?

    public init(
        message: String,
        conversationId: String,
        context: ContextPacket?,
        session: SessionStore,
        mode: String = "normal",
        intent: String? = nil,
        requiresScreenContext: Bool? = nil
    ) {
        self.message = message
        self.conversationId = conversationId
        self.context = context
        self.session = session
        self.mode = mode
        self.intent = intent
        self.requiresScreenContext = requiresScreenContext
    }
}
