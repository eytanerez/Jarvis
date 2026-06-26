import Foundation
import JarvisCore

public enum FileIndexClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case badStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "The file index URL is invalid."
        case .badStatus(let status): "The file index returned HTTP \(status)."
        }
    }
}

public struct FileIndexStatusReport: Codable, Equatable, Sendable {
    public var indexedFolders: [String]
    public var fileCount: Int
    public var lastIndexTime: Date?
    public var currentlyIndexing: Bool
    public var watching: Bool
    public var failedFiles: [String]
    public var storageSize: Int
    public var embeddingBackend: String

    public init(
        indexedFolders: [String] = [],
        fileCount: Int = 0,
        lastIndexTime: Date? = nil,
        currentlyIndexing: Bool = false,
        watching: Bool = false,
        failedFiles: [String] = [],
        storageSize: Int = 0,
        embeddingBackend: String = "none_mvp"
    ) {
        self.indexedFolders = indexedFolders
        self.fileCount = fileCount
        self.lastIndexTime = lastIndexTime
        self.currentlyIndexing = currentlyIndexing
        self.watching = watching
        self.failedFiles = failedFiles
        self.storageSize = storageSize
        self.embeddingBackend = embeddingBackend
    }
}

public struct FileSearchRequest: Codable, Equatable, Sendable {
    public var query: String
    public var limit: Int
    public var folders: [String]?
    public var extensions: [String]?
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?

    public init(
        query: String,
        limit: Int = 8,
        folders: [String]? = nil,
        extensions: [String]? = nil,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil
    ) {
        self.query = query
        self.limit = limit
        self.folders = folders
        self.extensions = extensions
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
    }
}

public struct FileSearchResponse: Codable, Equatable, Sendable {
    public var results: [FileContextSnippet]
}

public struct FileReadRequest: Codable, Equatable, Sendable {
    public var id: String?
    public var path: String?
    public var maxChars: Int

    public init(id: String? = nil, path: String? = nil, maxChars: Int = 24_000) {
        self.id = id
        self.path = path
        self.maxChars = maxChars
    }
}

public struct FileReadResponse: Codable, Equatable, Sendable {
    public var file: FileContextSnippet
    public var content: String
    public var truncated: Bool
}

public final class FileIndexClient: @unchecked Sendable {
    public var baseURL: URL
    public var token: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func start() async throws -> FileIndexStatusReport {
        try await postStatus(path: "/files/index/start", body: Data("{}".utf8))
    }

    public func stop() async throws -> FileIndexStatusReport {
        try await postStatus(path: "/files/index/stop", body: Data("{}".utf8))
    }

    public func reindex() async throws -> FileIndexStatusReport {
        try await postStatus(path: "/files/index/reindex", body: Data("{}".utf8), timeout: 120)
    }

    public func status() async throws -> FileIndexStatusReport {
        let data = try await get(path: "/files/index/status")
        return try decoder.decode(FileIndexStatusReport.self, from: data)
    }

    public func search(_ request: FileSearchRequest) async throws -> [FileContextSnippet] {
        let data = try encoder.encode(request)
        let response = try await post(path: "/files/search", body: data)
        return try decoder.decode(FileSearchResponse.self, from: response).results
    }

    public func read(_ request: FileReadRequest) async throws -> FileReadResponse {
        let data = try encoder.encode(request)
        let response = try await post(path: "/files/read", body: data)
        return try decoder.decode(FileReadResponse.self, from: response)
    }

    private func postStatus(path: String, body: Data, timeout: TimeInterval? = nil) async throws -> FileIndexStatusReport {
        let data = try await post(path: path, body: body, timeout: timeout)
        return try decoder.decode(FileIndexStatusReport.self, from: data)
    }

    private func get(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validate(response)
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
        try validate(response)
        return data
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw FileIndexClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Jarvis-Token")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw FileIndexClientError.badStatus(http.statusCode)
        }
    }
}
