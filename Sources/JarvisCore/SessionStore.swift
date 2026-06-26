import Foundation

public struct SessionStore: Codable, Equatable, Sendable {
    public var currentConversationId: String
    public var recentMessages: [ConversationMessage]
    public var lastStructuredResponse: StructuredResponse?
    public var lastResults: [StructuredResult]
    public var lastActions: [AssistantAction]
    public var lastOpenedURLs: [URL]
    public var lastSelectedEntity: StructuredResult?
    public var lastScreenContext: ContextPacket?
    public var targetAppSnapshot: TargetAppSnapshot?
    public var expiresAt: Date

    public init(
        currentConversationId: String = UUID().uuidString,
        recentMessages: [ConversationMessage] = [],
        lastStructuredResponse: StructuredResponse? = nil,
        lastResults: [StructuredResult] = [],
        lastActions: [AssistantAction] = [],
        lastOpenedURLs: [URL] = [],
        lastSelectedEntity: StructuredResult? = nil,
        lastScreenContext: ContextPacket? = nil,
        targetAppSnapshot: TargetAppSnapshot? = nil,
        expiresAt: Date = Date().addingTimeInterval(20 * 60)
    ) {
        self.currentConversationId = currentConversationId
        self.recentMessages = recentMessages
        self.lastStructuredResponse = lastStructuredResponse
        self.lastResults = lastResults
        self.lastActions = lastActions
        self.lastOpenedURLs = lastOpenedURLs
        self.lastSelectedEntity = lastSelectedEntity
        self.lastScreenContext = lastScreenContext
        self.targetAppSnapshot = targetAppSnapshot
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public mutating func touch(timeoutMinutes: Int) {
        expiresAt = Date().addingTimeInterval(TimeInterval(timeoutMinutes * 60))
    }

    public mutating func clear(timeoutMinutes: Int = 20) {
        self = SessionStore(expiresAt: Date().addingTimeInterval(TimeInterval(timeoutMinutes * 60)))
    }

    public mutating func record(user: String, response: StructuredResponse, timeoutMinutes: Int) {
        recentMessages.append(ConversationMessage(role: .user, content: user))
        recentMessages.append(ConversationMessage(role: .assistant, content: response.answer))
        if recentMessages.count > 20 {
            recentMessages.removeFirst(recentMessages.count - 20)
        }

        lastStructuredResponse = response
        if !response.results.isEmpty {
            lastResults = response.results
        }
        if !response.actions.isEmpty {
            lastActions = response.actions
            let opened = response.actions.flatMap(Self.urls(from:))
            if !opened.isEmpty {
                lastOpenedURLs = opened
            }
        }
        touch(timeoutMinutes: timeoutMinutes)
    }

    private static func urls(from action: AssistantAction) -> [URL] {
        if let url = action.payload["url"]?.stringValue.flatMap(URL.init(string:)) {
            return [url]
        }
        if let values = action.payload["urls"]?.arrayValue {
            return values.compactMap { $0.stringValue.flatMap(URL.init(string:)) }
        }
        return []
    }
}
