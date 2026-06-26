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

public struct SkillUpdate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var action: String?
    public var skillName: String?
    public var summary: String?
    public var stagedPath: String?
    public var targetPath: String?
    public var createdAt: String?
    public var warnings: [String]
    public var metadata: [String: JSONValue]?

    public init(
        id: String,
        action: String? = nil,
        skillName: String? = nil,
        summary: String? = nil,
        stagedPath: String? = nil,
        targetPath: String? = nil,
        createdAt: String? = nil,
        warnings: [String] = [],
        metadata: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.action = action
        self.skillName = skillName
        self.summary = summary
        self.stagedPath = stagedPath
        self.targetPath = targetPath
        self.createdAt = createdAt
        self.warnings = warnings
        self.metadata = metadata
    }
}

public struct ResponseMetadata: Codable, Equatable, Sendable {
    public var route: String?
    public var provider: String?
    public var model: String?
    public var modelRoute: String?
    public var taskType: String?
    public var why: String?
    public var latencyTargetMs: Int?
    public var privacyLevel: String?
    public var mode: String?
    public var intent: String?
    public var selectedCapability: String?
    public var selectedSkill: String?
    public var selectedBundle: String?
    public var skillLoaded: Bool?
    public var riskLevel: String?
    public var loadedSkills: [String]
    public var missingSkills: [String]
    public var bundleInvocation: String?
    public var trace: [String: JSONValue]?
    public var situation: [String: JSONValue]?
    public var usedMemory: Bool
    public var usedWeb: Bool
    public var usedScreenContext: Bool
    public var contextAvailable: Bool
    public var warnings: [String]
    public var webSearchMode: String?
    public var ttsEngine: String?
    public var mood: String?
    public var actionCount: Int?
    public var skillPromotionSuggestion: [String: JSONValue]?

    private enum CodingKeys: String, CodingKey {
        case route
        case provider
        case model
        case modelRoute
        case taskType
        case why
        case latencyTargetMs
        case privacyLevel
        case mode
        case intent
        case selectedCapability
        case selectedSkill
        case selectedBundle
        case skillLoaded
        case riskLevel
        case loadedSkills
        case missingSkills
        case bundleInvocation
        case trace
        case situation
        case usedMemory
        case usedWeb
        case usedScreenContext
        case contextAvailable
        case warnings
        case webSearchMode
        case ttsEngine
        case mood
        case actionCount
        case skillPromotionSuggestion
    }

    public init(
        route: String? = nil,
        provider: String? = nil,
        model: String? = nil,
        modelRoute: String? = nil,
        taskType: String? = nil,
        why: String? = nil,
        latencyTargetMs: Int? = nil,
        privacyLevel: String? = nil,
        mode: String? = nil,
        intent: String? = nil,
        selectedCapability: String? = nil,
        selectedSkill: String? = nil,
        selectedBundle: String? = nil,
        skillLoaded: Bool? = nil,
        riskLevel: String? = nil,
        loadedSkills: [String] = [],
        missingSkills: [String] = [],
        bundleInvocation: String? = nil,
        trace: [String: JSONValue]? = nil,
        situation: [String: JSONValue]? = nil,
        usedMemory: Bool = false,
        usedWeb: Bool = false,
        usedScreenContext: Bool = false,
        contextAvailable: Bool = false,
        warnings: [String] = [],
        webSearchMode: String? = nil,
        ttsEngine: String? = nil,
        mood: String? = nil,
        actionCount: Int? = nil,
        skillPromotionSuggestion: [String: JSONValue]? = nil
    ) {
        self.route = route
        self.provider = provider
        self.model = model
        self.modelRoute = modelRoute
        self.taskType = taskType
        self.why = why
        self.latencyTargetMs = latencyTargetMs
        self.privacyLevel = privacyLevel
        self.mode = mode
        self.intent = intent
        self.selectedCapability = selectedCapability
        self.selectedSkill = selectedSkill
        self.selectedBundle = selectedBundle
        self.skillLoaded = skillLoaded
        self.riskLevel = riskLevel
        self.loadedSkills = loadedSkills
        self.missingSkills = missingSkills
        self.bundleInvocation = bundleInvocation
        self.trace = trace
        self.situation = situation
        self.usedMemory = usedMemory
        self.usedWeb = usedWeb
        self.usedScreenContext = usedScreenContext
        self.contextAvailable = contextAvailable
        self.warnings = warnings
        self.webSearchMode = webSearchMode
        self.ttsEngine = ttsEngine
        self.mood = mood
        self.actionCount = actionCount
        self.skillPromotionSuggestion = skillPromotionSuggestion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        modelRoute = try container.decodeIfPresent(String.self, forKey: .modelRoute)
        taskType = try container.decodeIfPresent(String.self, forKey: .taskType)
        why = try container.decodeIfPresent(String.self, forKey: .why)
        latencyTargetMs = try container.decodeIfPresent(Int.self, forKey: .latencyTargetMs)
        privacyLevel = try container.decodeIfPresent(String.self, forKey: .privacyLevel)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
        selectedCapability = try container.decodeIfPresent(String.self, forKey: .selectedCapability)
        selectedSkill = try container.decodeIfPresent(String.self, forKey: .selectedSkill)
        selectedBundle = try container.decodeIfPresent(String.self, forKey: .selectedBundle)
        skillLoaded = try container.decodeIfPresent(Bool.self, forKey: .skillLoaded)
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
        loadedSkills = try container.decodeIfPresent([String].self, forKey: .loadedSkills) ?? []
        missingSkills = try container.decodeIfPresent([String].self, forKey: .missingSkills) ?? []
        bundleInvocation = try container.decodeIfPresent(String.self, forKey: .bundleInvocation)
        trace = try container.decodeIfPresent([String: JSONValue].self, forKey: .trace)
        situation = try container.decodeIfPresent([String: JSONValue].self, forKey: .situation)
        usedMemory = try container.decodeIfPresent(Bool.self, forKey: .usedMemory) ?? false
        usedWeb = try container.decodeIfPresent(Bool.self, forKey: .usedWeb) ?? false
        usedScreenContext = try container.decodeIfPresent(Bool.self, forKey: .usedScreenContext) ?? false
        contextAvailable = try container.decodeIfPresent(Bool.self, forKey: .contextAvailable) ?? false
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        webSearchMode = try container.decodeIfPresent(String.self, forKey: .webSearchMode)
        ttsEngine = try container.decodeIfPresent(String.self, forKey: .ttsEngine)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
        actionCount = try container.decodeIfPresent(Int.self, forKey: .actionCount)
        skillPromotionSuggestion = try container.decodeIfPresent([String: JSONValue].self, forKey: .skillPromotionSuggestion)
    }
}

public struct StructuredResponse: Codable, Equatable, Sendable {
    public var answer: String
    public var speak: String
    public var results: [StructuredResult]
    public var actions: [AssistantAction]
    public var memoryUpdates: [MemoryUpdate]
    public var skillUpdates: [SkillUpdate]
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
        skillUpdates: [SkillUpdate] = [],
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
        self.skillUpdates = skillUpdates
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
        case skillUpdates
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
        skillUpdates = try container.decodeIfPresent([SkillUpdate].self, forKey: .skillUpdates) ?? []
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
        try container.encode(skillUpdates, forKey: .skillUpdates)
        try container.encode(requiresConfirmation, forKey: .requiresConfirmation)
        try container.encodeIfPresent(confirmation, forKey: .confirmation)
        try container.encodeIfPresent(modelUsed, forKey: .modelUsed)
        try container.encode(metadata, forKey: .metadata)
    }
}
