import Darwin
import Foundation

public struct BrowserContext: Codable, Equatable, Sendable {
    public var browser: String?
    public var title: String?
    public var url: URL?
    public var selectedText: String?
    public var pageText: String?

    public init(browser: String? = nil, title: String? = nil, url: URL? = nil, selectedText: String? = nil, pageText: String? = nil) {
        self.browser = browser
        self.title = title
        self.url = url
        self.selectedText = selectedText
        self.pageText = pageText
    }
}

public enum BrowserReadError: Codable, Equatable, Error, Sendable {
    case notBrowser(appName: String)
    case automationPermissionDenied(appName: String)
    case javascriptFromAppleEventsDisabled(browser: String)
    case noBrowserWindow(browser: String)
    case emptyPageText(browser: String, url: String?)
    case scriptFailed(browser: String, message: String)

    public var code: String {
        switch self {
        case .notBrowser: "notBrowser"
        case .automationPermissionDenied: "automationPermissionDenied"
        case .javascriptFromAppleEventsDisabled: "javascriptFromAppleEventsDisabled"
        case .noBrowserWindow: "noBrowserWindow"
        case .emptyPageText: "emptyPageText"
        case .scriptFailed: "scriptFailed"
        }
    }

    public var message: String {
        switch self {
        case .notBrowser(let appName):
            "\(appName) is not a supported browser."
        case .automationPermissionDenied(let appName):
            "I can't read \(appName) yet. I need Automation permission for \(appName)."
        case .javascriptFromAppleEventsDisabled(let browser):
            "I can't read \(browser) yet. I need \(browser)'s Allow JavaScript from Apple Events setting enabled."
        case .noBrowserWindow(let browser):
            "I captured \(browser), but it does not have an open browser window."
        case .emptyPageText(let browser, _):
            "I captured \(browser), but the page text came back empty. Try selecting text or enabling the browser reader."
        case .scriptFailed(let browser, let message):
            "\(browser) browser reading failed: \(message)"
        }
    }

    public var appName: String? {
        switch self {
        case .notBrowser(let appName), .automationPermissionDenied(let appName):
            appName
        case .javascriptFromAppleEventsDisabled(let browser),
             .noBrowserWindow(let browser),
             .emptyPageText(let browser, _),
             .scriptFailed(let browser, _):
            browser
        }
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case appName
        case browser
        case url
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .code)
        let appName = try container.decodeIfPresent(String.self, forKey: .appName)
        let browser = try container.decodeIfPresent(String.self, forKey: .browser)
        let message = try container.decodeIfPresent(String.self, forKey: .message)
        let url = try container.decodeIfPresent(String.self, forKey: .url)

        switch code {
        case "notBrowser", "unsupportedBrowser":
            self = .notBrowser(appName: appName ?? browser ?? "Unknown app")
        case "automationPermissionDenied", "automationDenied":
            self = .automationPermissionDenied(appName: appName ?? browser ?? "the captured browser")
        case "javascriptFromAppleEventsDisabled", "javascriptDenied":
            self = .javascriptFromAppleEventsDisabled(browser: browser ?? appName ?? "the browser")
        case "noBrowserWindow":
            self = .noBrowserWindow(browser: browser ?? appName ?? "the browser")
        case "emptyPageText", "invalidOutput":
            self = .emptyPageText(browser: browser ?? appName ?? "the browser", url: url)
        case "scriptFailed", "scriptFailure":
            self = .scriptFailed(browser: browser ?? appName ?? "the browser", message: message ?? "Browser automation failed.")
        default:
            self = .scriptFailed(browser: browser ?? appName ?? "the browser", message: message ?? "Browser automation failed.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        switch self {
        case .notBrowser(let appName), .automationPermissionDenied(let appName):
            try container.encode(appName, forKey: .appName)
        case .javascriptFromAppleEventsDisabled(let browser),
             .noBrowserWindow(let browser):
            try container.encode(browser, forKey: .browser)
        case .emptyPageText(let browser, let url):
            try container.encode(browser, forKey: .browser)
            try container.encodeIfPresent(url, forKey: .url)
        case .scriptFailed(let browser, let message):
            try container.encode(browser, forKey: .browser)
            try container.encode(message, forKey: .message)
        }
    }
}

public struct AccessibilityContext: Codable, Equatable, Sendable {
    public var frontmostApp: String?
    public var windowTitle: String?
    public var visibleText: String?
    public var buttons: [String]
    public var fields: [String]

    public init(
        frontmostApp: String? = nil,
        windowTitle: String? = nil,
        visibleText: String? = nil,
        buttons: [String] = [],
        fields: [String] = []
    ) {
        self.frontmostApp = frontmostApp
        self.windowTitle = windowTitle
        self.visibleText = visibleText
        self.buttons = buttons
        self.fields = fields
    }
}

public struct DocumentContext: Codable, Equatable, Sendable {
    public var appName: String?
    public var documentTitle: String?
    public var documentPath: String?
    public var fileExtension: String?
    public var selectedText: String?
    public var currentParagraph: String?
    public var previousParagraph: String?
    public var nextParagraph: String?
    public var textPreview: String?
    public var textLength: Int
    public var source: String
    public var capturedAt: Date

    public init(
        appName: String? = nil,
        documentTitle: String? = nil,
        documentPath: String? = nil,
        fileExtension: String? = nil,
        selectedText: String? = nil,
        currentParagraph: String? = nil,
        previousParagraph: String? = nil,
        nextParagraph: String? = nil,
        textPreview: String? = nil,
        textLength: Int = 0,
        source: String = "active_document",
        capturedAt: Date = Date()
    ) {
        self.appName = appName
        self.documentTitle = documentTitle
        self.documentPath = documentPath
        self.fileExtension = fileExtension
        self.selectedText = selectedText
        self.currentParagraph = currentParagraph
        self.previousParagraph = previousParagraph
        self.nextParagraph = nextParagraph
        self.textPreview = textPreview
        self.textLength = textLength
        self.source = source
        self.capturedAt = capturedAt
    }

    public var hasAnyText: Bool {
        [selectedText, currentParagraph, previousParagraph, nextParagraph, textPreview]
            .contains { !($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct FileContextSnippet: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var path: String
    public var filename: String
    public var extensionName: String?
    public var mimeType: String?
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var lastIndexedAt: Date?
    public var textPreview: String?
    public var score: Double?
    public var tags: [String]
    public var source: String

    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case filename
        case extensionName = "extension"
        case mimeType
        case createdAt
        case modifiedAt
        case lastIndexedAt
        case textPreview
        case score
        case tags
        case source
    }

    public init(
        id: String,
        path: String,
        filename: String,
        extensionName: String? = nil,
        mimeType: String? = nil,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        lastIndexedAt: Date? = nil,
        textPreview: String? = nil,
        score: Double? = nil,
        tags: [String] = [],
        source: String = "local_file"
    ) {
        self.id = id
        self.path = path
        self.filename = filename
        self.extensionName = extensionName
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastIndexedAt = lastIndexedAt
        self.textPreview = textPreview
        self.score = score
        self.tags = tags
        self.source = source
    }
}

public struct MemorySnippet: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var category: String?
    public var confidence: Double?
    public var source: String?
    public var createdAt: Date?
    public var lastUsedAt: Date?

    public init(
        id: String,
        text: String,
        category: String? = nil,
        confidence: Double? = nil,
        source: String? = nil,
        createdAt: Date? = nil,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

public struct ContextWarning: Codable, Equatable, Sendable, Identifiable, Error {
    public var id: String
    public var code: String
    public var message: String
    public var source: String?

    public init(id: String = UUID().uuidString, code: String, message: String, source: String? = nil) {
        self.id = id
        self.code = code
        self.message = message
        self.source = source
    }
}

public struct UserProfileContext: Codable, Equatable, Sendable {
    public var name: String?
    public var communicationStyle: String?
    public var currentProjects: [String]
    public var preferredProvider: String?
    public var assistantPreference: String?
    public var writingStyle: String?
    public var importantPeople: [String]
    public var standingInstructions: [String]

    public init(
        name: String? = nil,
        communicationStyle: String? = nil,
        currentProjects: [String] = [],
        preferredProvider: String? = nil,
        assistantPreference: String? = nil,
        writingStyle: String? = nil,
        importantPeople: [String] = [],
        standingInstructions: [String] = []
    ) {
        self.name = name
        self.communicationStyle = communicationStyle
        self.currentProjects = currentProjects
        self.preferredProvider = preferredProvider
        self.assistantPreference = assistantPreference
        self.writingStyle = writingStyle
        self.importantPeople = importantPeople
        self.standingInstructions = standingInstructions
    }
}

public struct ScheduleItemContext: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var title: String
    public var calendarTitle: String?
    public var start: Date
    public var end: Date?
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var url: URL?
    public var participantNames: [String]
    public var completed: Bool?

    public init(
        id: String,
        kind: String,
        title: String,
        calendarTitle: String? = nil,
        start: Date,
        end: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        participantNames: [String] = [],
        completed: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.calendarTitle = calendarTitle
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.participantNames = participantNames
        self.completed = completed
    }
}

public struct ScheduleContext: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var calendarAuthorization: String
    public var reminderAuthorization: String
    public var events: [ScheduleItemContext]
    public var reminders: [ScheduleItemContext]

    public init(
        generatedAt: Date = Date(),
        calendarAuthorization: String = "unknown",
        reminderAuthorization: String = "unknown",
        events: [ScheduleItemContext] = [],
        reminders: [ScheduleItemContext] = []
    ) {
        self.generatedAt = generatedAt
        self.calendarAuthorization = calendarAuthorization
        self.reminderAuthorization = reminderAuthorization
        self.events = events
        self.reminders = reminders
    }

    public var hasAnyEntries: Bool {
        !events.isEmpty || !reminders.isEmpty
    }
}

public struct TargetAppSnapshot: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String?
    public var processIdentifier: pid_t
    public var windowTitle: String?
    public var capturedAt: Date

    public init(
        appName: String = "Unknown",
        bundleIdentifier: String? = nil,
        processIdentifier: pid_t = 0,
        windowTitle: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.windowTitle = windowTitle
        self.capturedAt = capturedAt
    }
}

public typealias ActiveAppSnapshot = TargetAppSnapshot
public typealias ContextPack = ContextPacket

public struct ContextPacket: Codable, Equatable, Sendable {
    public var frontmostApp: String?
    public var activeApp: ActiveAppSnapshot?
    public var targetApp: TargetAppSnapshot?
    public var selectedText: String?
    public var surroundingText: String?
    public var documentContext: DocumentContext?
    public var browser: BrowserContext?
    public var browserError: BrowserReadError?
    public var accessibility: AccessibilityContext?
    public var schedule: ScheduleContext?
    public var relevantFiles: [FileContextSnippet]
    public var relevantMemories: [MemorySnippet]
    public var userProfile: UserProfileContext?
    public var warnings: [ContextWarning]
    public var screenshotFallbackAvailable: Bool
    public var timestamp: Date

    public init(
        frontmostApp: String? = nil,
        activeApp: ActiveAppSnapshot? = nil,
        targetApp: TargetAppSnapshot? = nil,
        selectedText: String? = nil,
        surroundingText: String? = nil,
        documentContext: DocumentContext? = nil,
        browser: BrowserContext? = nil,
        browserError: BrowserReadError? = nil,
        accessibility: AccessibilityContext? = nil,
        schedule: ScheduleContext? = nil,
        relevantFiles: [FileContextSnippet] = [],
        relevantMemories: [MemorySnippet] = [],
        userProfile: UserProfileContext? = nil,
        warnings: [ContextWarning] = [],
        screenshotFallbackAvailable: Bool = false,
        timestamp: Date = Date()
    ) {
        self.frontmostApp = frontmostApp
        self.activeApp = activeApp
        self.targetApp = targetApp
        self.selectedText = selectedText
        self.surroundingText = surroundingText
        self.documentContext = documentContext
        self.browser = browser
        self.browserError = browserError
        self.accessibility = accessibility
        self.schedule = schedule
        self.relevantFiles = relevantFiles
        self.relevantMemories = relevantMemories
        self.userProfile = userProfile
        self.warnings = warnings
        self.screenshotFallbackAvailable = screenshotFallbackAvailable
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case frontmostApp
        case activeApp
        case targetApp
        case selectedText
        case surroundingText
        case documentContext
        case browser
        case browserError
        case accessibility
        case schedule
        case relevantFiles
        case relevantMemories
        case userProfile
        case warnings
        case screenshotFallbackAvailable
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frontmostApp = try container.decodeIfPresent(String.self, forKey: .frontmostApp)
        activeApp = try container.decodeIfPresent(ActiveAppSnapshot.self, forKey: .activeApp)
        targetApp = try container.decodeIfPresent(TargetAppSnapshot.self, forKey: .targetApp)
        if activeApp == nil {
            activeApp = targetApp
        }
        selectedText = try container.decodeIfPresent(String.self, forKey: .selectedText)
        surroundingText = try container.decodeIfPresent(String.self, forKey: .surroundingText)
        documentContext = try container.decodeIfPresent(DocumentContext.self, forKey: .documentContext)
        browser = try container.decodeIfPresent(BrowserContext.self, forKey: .browser)
        browserError = try container.decodeIfPresent(BrowserReadError.self, forKey: .browserError)
        accessibility = try container.decodeIfPresent(AccessibilityContext.self, forKey: .accessibility)
        schedule = try container.decodeIfPresent(ScheduleContext.self, forKey: .schedule)
        relevantFiles = try container.decodeIfPresent([FileContextSnippet].self, forKey: .relevantFiles) ?? []
        relevantMemories = try container.decodeIfPresent([MemorySnippet].self, forKey: .relevantMemories) ?? []
        userProfile = try container.decodeIfPresent(UserProfileContext.self, forKey: .userProfile)
        warnings = try container.decodeIfPresent([ContextWarning].self, forKey: .warnings) ?? []
        screenshotFallbackAvailable = try container.decodeIfPresent(Bool.self, forKey: .screenshotFallbackAvailable) ?? false
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(frontmostApp, forKey: .frontmostApp)
        try container.encodeIfPresent(activeApp, forKey: .activeApp)
        try container.encodeIfPresent(targetApp, forKey: .targetApp)
        try container.encodeIfPresent(selectedText, forKey: .selectedText)
        try container.encodeIfPresent(surroundingText, forKey: .surroundingText)
        try container.encodeIfPresent(documentContext, forKey: .documentContext)
        try container.encodeIfPresent(browser, forKey: .browser)
        try container.encodeIfPresent(browserError, forKey: .browserError)
        try container.encodeIfPresent(accessibility, forKey: .accessibility)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encode(relevantFiles, forKey: .relevantFiles)
        try container.encode(relevantMemories, forKey: .relevantMemories)
        try container.encodeIfPresent(userProfile, forKey: .userProfile)
        try container.encode(warnings, forKey: .warnings)
        try container.encode(screenshotFallbackAvailable, forKey: .screenshotFallbackAvailable)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public var hasAnyText: Bool {
        func hasText(_ text: String?) -> Bool {
            !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return hasText(selectedText)
            || hasText(surroundingText)
            || hasText(browser?.selectedText)
            || hasText(browser?.pageText)
            || (documentContext?.hasAnyText == true)
            || hasText(accessibility?.visibleText)
    }

    public var hasScheduleContext: Bool {
        schedule != nil
    }

    public var hasDocumentContext: Bool {
        documentContext?.hasAnyText == true
    }

    public var hasScreenOrBrowserText: Bool {
        func hasText(_ text: String?) -> Bool {
            !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return hasText(selectedText)
            || hasText(surroundingText)
            || hasText(browser?.selectedText)
            || hasText(browser?.pageText)
            || (documentContext?.hasAnyText == true)
            || hasText(accessibility?.visibleText)
    }
}
