import Foundation

public enum AssistantPhase: Equatable, Sendable {
    case idle
    case listening
    case transcribing(String)
    case thinking
    case acting(String)
    case speaking(String)
    case results(StructuredResponse)
    case confirming(ConfirmationRequest)
    case error(String)

    public var title: String {
        switch self {
        case .idle: "Ready"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .thinking: "Thinking"
        case .acting: "Acting"
        case .speaking: "Speaking"
        case .results: "Results"
        case .confirming: "Confirm"
        case .error: "Error"
        }
    }
}

public enum TurnStatus: String, Codable, Equatable, Sendable {
    case listening
    case routing
    case collectingContext
    case callingBrain
    case speaking
    case complete
    case failed
    case cancelled
}

public struct AssistantTurn: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var transcript: String
    public var status: TurnStatus
    public var startedAt: Date

    public init(
        id: UUID = UUID(),
        transcript: String,
        status: TurnStatus,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.transcript = transcript
        self.status = status
        self.startedAt = startedAt
    }
}

public struct ConversationMessage: Codable, Equatable, Sendable, Identifiable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    public var id: UUID
    public var role: Role
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public struct StructuredResult: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var rank: Int?
    public var name: String
    public var url: URL?
    public var price: String?
    public var reason: String?
    public var metadata: [String: JSONValue]

    public init(
        id: String,
        rank: Int? = nil,
        name: String,
        url: URL? = nil,
        price: String? = nil,
        reason: String? = nil,
        metadata: [String: JSONValue] = [:]
    ) {
        self.id = id
        self.rank = rank
        self.name = name
        self.url = url
        self.price = price
        self.reason = reason
        self.metadata = metadata
    }
}

public struct AssistantAction: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: String
    public var payload: [String: JSONValue]

    public init(id: String = UUID().uuidString, type: String, payload: [String: JSONValue] = [:]) {
        self.id = id
        self.type = type
        self.payload = payload
    }
}

public enum ActionRisk: String, Codable, Equatable, Sendable {
    case green
    case yellow
    case red
}

public struct ConfirmationRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var risk: ActionRisk
    public var title: String
    public var description: String
    public var action: AssistantAction
    public var requiresTypedConfirmation: Bool

    public init(
        id: String = UUID().uuidString,
        risk: ActionRisk,
        title: String,
        description: String,
        action: AssistantAction,
        requiresTypedConfirmation: Bool = false
    ) {
        self.id = id
        self.risk = risk
        self.title = title
        self.description = description
        self.action = action
        self.requiresTypedConfirmation = requiresTypedConfirmation
    }
}

public struct MemoryUpdate: Codable, Equatable, Sendable {
    public var text: String
    public var metadata: [String: JSONValue]

    public init(text: String, metadata: [String: JSONValue] = [:]) {
        self.text = text
        self.metadata = metadata
    }
}

public struct ResponseMetadata: Codable, Equatable, Sendable {
    public var route: String?
    public var provider: String?
    public var model: String?
    public var usedMemory: Bool
    public var usedWeb: Bool
    public var usedScreenContext: Bool
    public var contextAvailable: Bool
    public var warnings: [String]
    public var webSearchMode: String?
    public var ttsEngine: String?
    public var mood: String?
    public var actionCount: Int?

    public init(
        route: String? = nil,
        provider: String? = nil,
        model: String? = nil,
        usedMemory: Bool = false,
        usedWeb: Bool = false,
        usedScreenContext: Bool = false,
        contextAvailable: Bool = false,
        warnings: [String] = [],
        webSearchMode: String? = nil,
        ttsEngine: String? = nil,
        mood: String? = nil,
        actionCount: Int? = nil
    ) {
        self.route = route
        self.provider = provider
        self.model = model
        self.usedMemory = usedMemory
        self.usedWeb = usedWeb
        self.usedScreenContext = usedScreenContext
        self.contextAvailable = contextAvailable
        self.warnings = warnings
        self.webSearchMode = webSearchMode
        self.ttsEngine = ttsEngine
        self.mood = mood
        self.actionCount = actionCount
    }
}

public struct StructuredResponse: Codable, Equatable, Sendable {
    public var answer: String
    public var speak: String
    public var results: [StructuredResult]
    public var actions: [AssistantAction]
    public var memoryUpdates: [MemoryUpdate]
    public var requiresConfirmation: Bool
    public var confirmation: ConfirmationRequest?
    public var modelUsed: String?
    public var metadata: ResponseMetadata

    public init(
        answer: String,
        speak: String? = nil,
        results: [StructuredResult] = [],
        actions: [AssistantAction] = [],
        memoryUpdates: [MemoryUpdate] = [],
        requiresConfirmation: Bool = false,
        confirmation: ConfirmationRequest? = nil,
        modelUsed: String? = nil,
        metadata: ResponseMetadata = ResponseMetadata()
    ) {
        self.answer = answer
        self.speak = speak ?? answer
        self.results = results
        self.actions = actions
        self.memoryUpdates = memoryUpdates
        self.requiresConfirmation = requiresConfirmation
        self.confirmation = confirmation
        self.modelUsed = modelUsed
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case answer
        case speak
        case results
        case actions
        case memoryUpdates
        case requiresConfirmation
        case confirmation
        case modelUsed
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answer = try container.decode(String.self, forKey: .answer)
        speak = try container.decodeIfPresent(String.self, forKey: .speak) ?? answer
        results = try container.decodeIfPresent([StructuredResult].self, forKey: .results) ?? []
        actions = try container.decodeIfPresent([AssistantAction].self, forKey: .actions) ?? []
        memoryUpdates = try container.decodeIfPresent([MemoryUpdate].self, forKey: .memoryUpdates) ?? []
        requiresConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? false
        confirmation = try container.decodeIfPresent(ConfirmationRequest.self, forKey: .confirmation)
        modelUsed = try container.decodeIfPresent(String.self, forKey: .modelUsed)
        metadata = try container.decodeIfPresent(ResponseMetadata.self, forKey: .metadata) ?? ResponseMetadata()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(answer, forKey: .answer)
        try container.encode(speak, forKey: .speak)
        try container.encode(results, forKey: .results)
        try container.encode(actions, forKey: .actions)
        try container.encode(memoryUpdates, forKey: .memoryUpdates)
        try container.encode(requiresConfirmation, forKey: .requiresConfirmation)
        try container.encodeIfPresent(confirmation, forKey: .confirmation)
        try container.encodeIfPresent(modelUsed, forKey: .modelUsed)
        try container.encode(metadata, forKey: .metadata)
    }
}
