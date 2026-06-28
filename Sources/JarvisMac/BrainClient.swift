import Foundation
import JarvisCore

public enum BrainClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case badStatus(Int)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "The brain URL is invalid."
        case .badStatus(let code): "The brain returned HTTP \(code)."
        case .emptyResponse: "The brain returned an empty response."
        }
    }
}

public struct ProviderTestReport: Codable, Equatable, Sendable {
    public var enabled: [String]
    public var results: [String: ProviderTestResult]
}

public struct ProviderTestResult: Codable, Equatable, Sendable {
    public var ok: Bool
    public var model: String?
    public var message: String
}

public struct ProviderDiagnosticsReport: Codable, Equatable, Sendable {
    public var enabled: [String]
    public var attempts: [ProviderAttempt]
}

public struct ProviderAttempt: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(timestamp)-\(provider)-\(taskType)-\(model ?? "")" }
    public var timestamp: String
    public var provider: String
    public var taskType: String
    public var model: String?
    public var ok: Bool
    public var message: String
}

public struct MemoryStatusReport: Codable, Equatable, Sendable {
    public var activeProvider: String
    public var activeModelProvider: String?
    public var activeModelProviderDisplayName: String?
    public var geminiKeyConfigured: Bool?
    public var brainReceivedGeminiKey: Bool?
    public var memoryBackend: String?
    public var fallbackReason: String?
    public var mem0Available: Bool
    public var mem0Provider: String?
    public var mem0EmbedderProvider: String?
    public var fallbackPath: String
    public var fallbackCount: Int
    public var lastError: String?
}

public struct TTSStatusReport: Codable, Equatable, Sendable {
    public var engine: String
    public var importable: Bool
    public var modelPresent: Bool
    public var voicesPresent: Bool
    public var cacheDirectory: String?
    public var f5TTSImportable: Bool?
    public var f5TTSDevice: String?
    public var f5TTSModel: String?
    public var lastError: String?
}

public struct PerformanceToggles: Codable, Equatable, Sendable {
    public var fileIndexDefaultMode: String
    public var backgroundFullIndexing: Bool
    public var f5TTSPreload: Bool
    public var memorySuggestions: Bool
    public var screenshotFallback: Bool
    public var shortestSpokenResponses: Bool
    public var richerContextPacks: Bool
}

public struct PerformanceModeReport: Codable, Equatable, Sendable {
    public var mode: String
    public var availableModes: [String]
    public var toggles: PerformanceToggles
}

public struct DashboardFileIndex: Codable, Equatable, Sendable {
    public var mode: String?
    public var currentlyIndexing: Bool?
    public var currentFile: String?
    public var fileCount: Int?
    public var filesScannedThisRun: Int?
    public var filesSkippedThisRun: Int?
    public var watching: Bool?
    public var lastFullReindexAt: String?
    public var lastIncrementalScanAt: String?
}

public struct DashboardTTS: Codable, Equatable, Sendable {
    public var engineLoaded: String?
    public var kokoroLoaded: Bool?
    public var f5TTSLoaded: Bool?
    public var f5TTSWorkerRunning: Bool?
    public var f5TTSImportable: Bool?
    public var lastEngineUsed: String?
    public var lastLatencyMs: Double?
}

public struct DashboardProviders: Codable, Equatable, Sendable {
    public var lastModelUsed: String?
    public var lastLatencyMs: Double?
    public var lastGeminiLatencyMs: Double?
    public var latencyByProvider: [String: Double]?
}

public struct DashboardChat: Codable, Equatable, Sendable {
    public var lastRoute: String?
    public var lastContextPackSize: Int?
}

public struct DashboardService: Codable, Equatable, Sendable, Identifiable {
    public var name: String
    public var running: Bool
    public var id: String { name }
}

public struct DashboardReport: Codable, Equatable, Sendable {
    public var brainRunning: Bool?
    public var performanceMode: String?
    public var fileIndex: DashboardFileIndex?
    public var tts: DashboardTTS?
    public var providers: DashboardProviders?
    public var chat: DashboardChat?
    public var backgroundServices: [DashboardService]?
}

public struct AssistantModeReport: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var purpose: String
    public var trigger: String
    public var executionType: String
    public var defaultModelRoute: String
    public var allowedSkills: [String]
    public var contextPolicy: [String: JSONValue]
    public var responseStyle: String
    public var riskPolicy: [String: JSONValue]
    public var maxResponseLength: String
    public var speechPolicy: [String: JSONValue]
}

public struct AssistantModeListReport: Codable, Equatable, Sendable {
    public var modes: [AssistantModeReport]
    public var defaultMode: String
}

public struct JarvisIdentityReport: Codable, Equatable, Sendable {
    public var name: String
    public var product: String
    public var personality: String?
    public var operatingEnvironment: String?
    public var coreRules: [String]?
    public var privacyRules: [String]?
    public var actionRules: [String]?

    private enum CodingKeys: String, CodingKey {
        case name
        case product
        case personality
        case operatingEnvironment = "operating_environment"
        case coreRules = "core_rules"
        case privacyRules = "privacy_rules"
        case actionRules = "action_rules"
    }
}

public struct CapabilitySummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var category: String
    public var examples: [String]
    public var enabled: Bool
    public var available: Bool
    public var source: String
    public var requiredPermissions: [String]
    public var requiredConnectors: [String]
    public var requiredSecrets: [String]
    public var allowedModes: [String]
    public var riskLevel: String
    public var requiresConfirmation: Bool
    public var limitations: [String]
    public var howToUse: String
    public var statusReason: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case examples
        case enabled
        case available
        case source
        case requiredPermissions = "required_permissions"
        case requiredConnectors = "required_connectors"
        case requiredSecrets = "required_secrets"
        case allowedModes = "allowed_modes"
        case riskLevel = "risk_level"
        case requiresConfirmation = "requires_confirmation"
        case limitations
        case howToUse = "how_to_use"
        case statusReason = "status_reason"
    }
}

public struct CapabilityReportSummary: Codable, Equatable, Sendable {
    public var availableCount: Int?
    public var unavailableCount: Int?
    public var skillCount: Int?

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case unavailableCount = "unavailable_count"
        case skillCount = "skill_count"
    }
}

public struct CapabilityReport: Codable, Equatable, Sendable {
    public var identity: JarvisIdentityReport
    public var mode: String
    public var situation: [String: JSONValue]
    public var available: [CapabilitySummary]
    public var unavailable: [CapabilitySummary]
    public var installedSkills: [SkillSummary]
    public var actionRules: [String]
    public var contextBoundaries: [String]
    public var summary: CapabilityReportSummary?

    private enum CodingKeys: String, CodingKey {
        case identity
        case mode
        case situation
        case available
        case unavailable
        case installedSkills = "installed_skills"
        case actionRules = "action_rules"
        case contextBoundaries = "context_boundaries"
        case summary
    }
}

public struct CapabilityExplainReport: Codable, Equatable, Sendable {
    public var answer: String
}

public struct SkillSummary: Codable, Equatable, Sendable, Identifiable {
    public var name: String
    public var description: String
    public var category: String
    public var riskLevel: String
    public var allowedModes: [String]
    public var requiresConfirmation: Bool?
    public var warnings: [String]?
    public var score: Int?

    public var id: String { name }
}

public struct SkillDetail: Codable, Equatable, Sendable {
    public var name: String
    public var description: String?
    public var category: String?
    public var riskLevel: String?
    public var allowedModes: [String]?
    public var version: String?
    public var platforms: [String]?
    public var requiredConnectors: [String]?
    public var requiredPermissions: [String]?
    public var requiredSecrets: [String]?
    public var body: String?
    public var raw: String?
    public var path: String?
    public var warnings: [String]?
}

public struct SkillListReport: Codable, Equatable, Sendable {
    public var skills: [SkillSummary]
    public var config: [String: JSONValue]?
}

public struct SkillSearchReport: Codable, Equatable, Sendable {
    public var skills: [SkillSummary]
}

public struct PendingSkillChange: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var action: String
    public var skillName: String
    public var summary: String
    public var stagedPath: String
    public var targetPath: String
    public var createdAt: String
    public var warnings: [String]
}

public struct PendingSkillChangesReport: Codable, Equatable, Sendable {
    public var changes: [PendingSkillChange]
}

public struct PendingSkillDiff: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var action: String
    public var skillName: String
    public var summary: String
    public var stagedPath: String
    public var targetPath: String
    public var createdAt: String
    public var warnings: [String]
    public var diff: String
}

public struct SkillBundle: Codable, Equatable, Sendable, Identifiable {
    public var name: String
    public var description: String?
    public var skills: [String]
    public var instruction: String?
    public var path: String?

    public var id: String { name }
}

public struct SkillBundlesReport: Codable, Equatable, Sendable {
    public var bundles: [SkillBundle]
}

public struct SkillBundleRunReport: Codable, Equatable, Sendable {
    public var bundle: SkillBundle
    public var query: String
    public var loadedSkills: [SkillDetail]
    public var missingSkills: [String]
    public var warnings: [String]
    public var prompt: String
}

public struct SkillRunRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var timestamp: String
    public var kind: String
    public var name: String
    public var route: String
    public var status: String
    public var mode: String?
    public var intent: String?
    public var riskLevel: String?
    public var requiresConfirmation: Bool
    public var loadedSkills: [String]
    public var missingSkills: [String]
    public var warnings: [String]
    public var inputSummary: [String: JSONValue]
    public var metadata: [String: JSONValue]
}

public struct SkillRunHistoryReport: Codable, Equatable, Sendable {
    public var runs: [SkillRunRecord]
}

public struct SkillLearnReport: Codable, Equatable, Sendable {
    public var answer: String
    public var speak: String?
    public var skillUpdate: PendingSkillChange
    public var warnings: [String]?
}

public struct JarvisPrompt: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var description: String
    public var content: String
    public var source: String
    public var editable: Bool
    public var path: String?

    public init(
        id: String,
        title: String,
        description: String,
        content: String,
        source: String,
        editable: Bool,
        path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.source = source
        self.editable = editable
        self.path = path
    }
}

public struct PromptListReport: Codable, Equatable, Sendable {
    public var prompts: [JarvisPrompt]
}

public struct ScheduledAgent: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var type: String
    public var enabled: Bool
    public var time: String
    public var timezone: String
    public var sources: [String: Bool]
    public var requiresOptIn: Bool
    public var lastRunAt: String?
    public var nextRunAt: String?
    public var updatedAt: String?

    public init(
        id: String,
        name: String,
        description: String,
        type: String,
        enabled: Bool,
        time: String,
        timezone: String,
        sources: [String: Bool],
        requiresOptIn: Bool,
        lastRunAt: String? = nil,
        nextRunAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.enabled = enabled
        self.time = time
        self.timezone = timezone
        self.sources = sources
        self.requiresOptIn = requiresOptIn
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.updatedAt = updatedAt
    }
}

public extension ScheduledAgent {
    func isDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard enabled, type == "scheduled", let scheduled = scheduledDate(on: now, calendar: calendar) else {
            return false
        }
        return now >= scheduled && !hasRun(on: now, calendar: calendar)
    }

    func hasRun(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let lastRun = Self.parseDate(lastRunAt) else { return false }
        var resolved = calendar
        if let zone = TimeZone(identifier: timezone) {
            resolved.timeZone = zone
        }
        return resolved.isDate(lastRun, inSameDayAs: date)
    }

    func scheduledDate(on date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let parts = time.split(separator: ":", maxSplits: 1).compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else {
            return nil
        }
        var resolved = calendar
        if let zone = TimeZone(identifier: timezone) {
            resolved.timeZone = zone
        }
        var components = resolved.dateComponents([.year, .month, .day], from: date)
        components.hour = parts[0]
        components.minute = parts[1]
        components.second = 0
        return resolved.date(from: components)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }
}

public struct ScheduledAgentListReport: Codable, Equatable, Sendable {
    public var agents: [ScheduledAgent]
}

public struct ScheduledAgentPreviewReport: Codable, Equatable, Sendable {
    public var agent: ScheduledAgent
    public var answer: String
    public var speak: String
    public var sourcesUsed: [String]
    public var metadata: ResponseMetadata?
}

public struct DictationStatusReport: Codable, Equatable, Sendable {
    public var available: Bool
    public var recording: Bool
    public var sttEngines: [String]
    public var postProcessing: [String]
}

public struct DictationTextReport: Codable, Equatable, Sendable {
    public var text: String
    public var activeApp: String?
}

private struct SkillLearnRequest: Codable, Sendable {
    var source: String
    var name: String?
    var category: String
    var mode: String
}

private struct SkillBundleRunRequest: Codable, Sendable {
    var name: String
    var query: String
}

private struct PromptSaveItem: Codable, Sendable {
    var id: String
    var content: String
}

private struct PromptSaveRequest: Codable, Sendable {
    var prompts: [PromptSaveItem]
}

private struct ScheduledAgentUpdateRequest: Codable, Sendable {
    var enabled: Bool?
    var time: String?
    var timezone: String?
    var sources: [String: Bool]?
}

private struct ScheduledAgentPreviewRequest: Codable, Sendable {
    var schedule: ScheduleContext?
}

private struct ScheduledAgentRunRequest: Codable, Sendable {
    var runAt: String
}

private struct DictationTextRequest: Codable, Sendable {
    var text: String
    var activeApp: String?
}

public struct TTSSynthesisRequest: Codable, Equatable, Sendable {
    public var text: String
    public var engine: String
    public var voice: String
    public var speed: Double
    public var referenceAudioPath: String?
    public var referenceText: String?
    public var cfgStrength: Double?
    public var nfeStep: Int?

    public init(
        text: String,
        engine: String = "kokoro",
        voice: String,
        speed: Double,
        referenceAudioPath: String? = nil,
        referenceText: String? = nil,
        cfgStrength: Double? = nil,
        nfeStep: Int? = nil
    ) {
        self.text = text
        self.engine = engine
        self.voice = voice
        self.speed = speed
        self.referenceAudioPath = referenceAudioPath
        self.referenceText = referenceText
        self.cfgStrength = cfgStrength
        self.nfeStep = nfeStep
    }
}

public final class BrainClient: @unchecked Sendable {
    public var baseURL: URL
    public var token: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL = URL(string: "http://127.0.0.1:8765")!, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func health() async -> Bool {
        do {
            var request = try makeRequest(path: "/health", method: "GET")
            request.timeoutInterval = 1.5
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func chat(_ request: BrainChatRequest) async throws -> StructuredResponse {
        let data = try encoder.encode(request)
        let responseData = try await post(path: "/chat", body: data)
        return try decoder.decode(StructuredResponse.self, from: responseData)
    }

    public func addMemory(_ text: String) async throws -> StructuredResponse {
        let body = try encoder.encode(["text": text])
        let responseData = try await post(path: "/memory/add", body: body)
        return try decoder.decode(StructuredResponse.self, from: responseData)
    }

    public func testProviders() async throws -> ProviderTestReport {
        let responseData = try await post(path: "/providers/test", body: Data("{}".utf8))
        return try decoder.decode(ProviderTestReport.self, from: responseData)
    }

    public func providerDiagnostics() async throws -> ProviderDiagnosticsReport {
        let responseData = try await get(path: "/providers/diagnostics")
        return try decoder.decode(ProviderDiagnosticsReport.self, from: responseData)
    }

    public func memoryStatus() async throws -> MemoryStatusReport {
        let responseData = try await get(path: "/memory/status")
        return try decoder.decode(MemoryStatusReport.self, from: responseData)
    }

    public func ttsStatus() async throws -> TTSStatusReport {
        let responseData = try await get(path: "/tts/status")
        return try decoder.decode(TTSStatusReport.self, from: responseData)
    }

    public func performanceStatus() async throws -> PerformanceModeReport {
        let responseData = try await get(path: "/settings/performance")
        return try decoder.decode(PerformanceModeReport.self, from: responseData)
    }

    public func setPerformanceMode(_ mode: String) async throws -> PerformanceModeReport {
        let body = try encoder.encode(["mode": mode])
        let responseData = try await post(path: "/settings/performance", body: body)
        return try decoder.decode(PerformanceModeReport.self, from: responseData)
    }

    public func dashboard() async throws -> DashboardReport {
        let responseData = try await get(path: "/runtime/dashboard")
        return try decoder.decode(DashboardReport.self, from: responseData)
    }

    public func runtimeVersion() async throws -> BrainVersionReport {
        let responseData = try await get(path: "/runtime/version")
        return try decoder.decode(BrainVersionReport.self, from: responseData)
    }

    public func runtimeStatus() async throws -> RuntimeStatusReport {
        let responseData = try await get(path: "/runtime/status")
        return try decoder.decode(RuntimeStatusReport.self, from: responseData)
    }

    public func assistantModes() async throws -> AssistantModeListReport {
        let responseData = try await get(path: "/modes")
        return try decoder.decode(AssistantModeListReport.self, from: responseData)
    }

    public func capabilities() async throws -> CapabilityReport {
        let responseData = try await get(path: "/capabilities")
        return try decoder.decode(CapabilityReport.self, from: responseData)
    }

    public func explainCapabilities(query: String) async throws -> CapabilityExplainReport {
        let data = try encoder.encode(["query": query])
        let responseData = try await post(path: "/capabilities/explain", body: data)
        return try decoder.decode(CapabilityExplainReport.self, from: responseData)
    }

    public func skills() async throws -> SkillListReport {
        let responseData = try await get(path: "/skills")
        return try decoder.decode(SkillListReport.self, from: responseData)
    }

    public func skill(name: String) async throws -> SkillDetail {
        let responseData = try await get(path: "/skills/\(pathComponent(name))")
        return try decoder.decode(SkillDetail.self, from: responseData)
    }

    public func searchSkills(query: String, mode: String = "quick_assistant") async throws -> SkillSearchReport {
        let data = try encoder.encode(["query": query, "mode": mode])
        let responseData = try await post(path: "/skills/search", body: data)
        return try decoder.decode(SkillSearchReport.self, from: responseData)
    }

    public func pendingSkillChanges() async throws -> PendingSkillChangesReport {
        let responseData = try await get(path: "/skills/pending")
        return try decoder.decode(PendingSkillChangesReport.self, from: responseData)
    }

    public func pendingSkillDiff(id: String) async throws -> PendingSkillDiff {
        let responseData = try await get(path: "/skills/pending/\(pathComponent(id))/diff")
        return try decoder.decode(PendingSkillDiff.self, from: responseData)
    }

    public func approveSkillChange(id: String) async throws -> PendingSkillChange {
        let data = try encoder.encode(["id": id])
        let responseData = try await post(path: "/skills/approve", body: data)
        return try decoder.decode(PendingSkillChange.self, from: responseData)
    }

    public func rejectSkillChange(id: String) async throws -> PendingSkillChange {
        let data = try encoder.encode(["id": id])
        let responseData = try await post(path: "/skills/reject", body: data)
        return try decoder.decode(PendingSkillChange.self, from: responseData)
    }

    public func skillBundles() async throws -> SkillBundlesReport {
        let responseData = try await get(path: "/skills/bundles")
        return try decoder.decode(SkillBundlesReport.self, from: responseData)
    }

    public func skillRunHistory(limit: Int = 20) async throws -> SkillRunHistoryReport {
        let responseData = try await get(path: "/skills/history?limit=\(max(1, min(limit, 200)))")
        return try decoder.decode(SkillRunHistoryReport.self, from: responseData)
    }

    public func runSkillBundle(name: String, query: String = "") async throws -> SkillBundleRunReport {
        let data = try encoder.encode(SkillBundleRunRequest(name: name, query: query))
        let responseData = try await post(path: "/skills/bundles/run", body: data)
        return try decoder.decode(SkillBundleRunReport.self, from: responseData)
    }

    public func learnSkill(source: String, name: String? = nil, category: String = "personal", mode: String = "skill_learning") async throws -> SkillLearnReport {
        let request = SkillLearnRequest(
            source: source,
            name: name?.isEmpty == true ? nil : name,
            category: category,
            mode: mode
        )
        let data = try encoder.encode(request)
        let responseData = try await post(path: "/skills/learn", body: data)
        return try decoder.decode(SkillLearnReport.self, from: responseData)
    }

    public func prompts() async throws -> PromptListReport {
        let responseData = try await get(path: "/settings/prompts")
        return try decoder.decode(PromptListReport.self, from: responseData)
    }

    public func savePrompts(_ prompts: [JarvisPrompt]) async throws -> PromptListReport {
        let items = prompts
            .filter { $0.editable }
            .map { PromptSaveItem(id: $0.id, content: $0.content) }
        let data = try encoder.encode(PromptSaveRequest(prompts: items))
        let responseData = try await post(path: "/settings/prompts", body: data)
        return try decoder.decode(PromptListReport.self, from: responseData)
    }

    public func scheduledAgents() async throws -> ScheduledAgentListReport {
        let responseData = try await get(path: "/scheduled-agents")
        return try decoder.decode(ScheduledAgentListReport.self, from: responseData)
    }

    public func updateScheduledAgent(
        id: String,
        enabled: Bool? = nil,
        time: String? = nil,
        timezone: String? = nil,
        sources: [String: Bool]? = nil
    ) async throws -> ScheduledAgent {
        let data = try encoder.encode(ScheduledAgentUpdateRequest(
            enabled: enabled,
            time: time,
            timezone: timezone,
            sources: sources
        ))
        let responseData = try await post(path: "/scheduled-agents/\(pathComponent(id))", body: data)
        return try decoder.decode(ScheduledAgent.self, from: responseData)
    }

    public func previewScheduledAgent(id: String, schedule: ScheduleContext?) async throws -> ScheduledAgentPreviewReport {
        let data = try encoder.encode(ScheduledAgentPreviewRequest(schedule: schedule))
        let responseData = try await post(path: "/scheduled-agents/\(pathComponent(id))/preview", body: data)
        return try decoder.decode(ScheduledAgentPreviewReport.self, from: responseData)
    }

    public func recordScheduledAgentRun(id: String, runAt: Date = Date()) async throws -> ScheduledAgent {
        let formatter = ISO8601DateFormatter()
        let data = try encoder.encode(ScheduledAgentRunRequest(runAt: formatter.string(from: runAt)))
        let responseData = try await post(path: "/scheduled-agents/\(pathComponent(id))/record-run", body: data)
        return try decoder.decode(ScheduledAgent.self, from: responseData)
    }

    public func dictationStatus() async throws -> DictationStatusReport {
        let responseData = try await get(path: "/dictation/status")
        return try decoder.decode(DictationStatusReport.self, from: responseData)
    }

    public func cleanDictation(_ text: String) async throws -> String {
        let data = try encoder.encode(DictationTextRequest(text: text, activeApp: nil))
        let responseData = try await post(path: "/dictation/clean", body: data)
        return try decoder.decode(DictationTextReport.self, from: responseData).text
    }

    public func formatDictation(_ text: String, activeApp: String?) async throws -> String {
        let data = try encoder.encode(DictationTextRequest(text: text, activeApp: activeApp))
        let responseData = try await post(path: "/dictation/format", body: data)
        return try decoder.decode(DictationTextReport.self, from: responseData).text
    }

    public func synthesizeSpeech(_ request: TTSSynthesisRequest) async throws -> Data {
        let data = try encoder.encode(request)
        return try await post(path: "/tts/synthesize", body: data, timeout: 300)
    }

    private func get(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BrainClientError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BrainClientError.badStatus(http.statusCode)
        }
        return data
    }

    private func post(path: String, body: Data, timeout: TimeInterval? = nil) async throws -> Data {
        var request = try makeRequest(path: path, method: "POST")
        if let timeout {
            request.timeoutInterval = timeout
        }
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BrainClientError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BrainClientError.badStatus(http.statusCode)
        }
        return data
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw BrainClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Jarvis-Token")
        return request
    }

    private func pathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
