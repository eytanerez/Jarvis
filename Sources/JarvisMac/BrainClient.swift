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
    public var chatterboxImportable: Bool?
    public var chatterboxDevice: String?
    public var lastError: String?
}

public struct TTSSynthesisRequest: Codable, Equatable, Sendable {
    public var text: String
    public var engine: String
    public var voice: String
    public var speed: Double
    public var referenceAudioPath: String?
    public var exaggeration: Double?
    public var cfgWeight: Double?
    public var stylePreset: String?

    public init(
        text: String,
        engine: String = "kokoro",
        voice: String,
        speed: Double,
        referenceAudioPath: String? = nil,
        exaggeration: Double? = nil,
        cfgWeight: Double? = nil,
        stylePreset: String? = nil
    ) {
        self.text = text
        self.engine = engine
        self.voice = voice
        self.speed = speed
        self.referenceAudioPath = referenceAudioPath
        self.exaggeration = exaggeration
        self.cfgWeight = cfgWeight
        self.stylePreset = stylePreset
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
}
