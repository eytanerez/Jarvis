import Foundation

/// How much reasoning a request needs from the cloud brain.
public enum BrainMode: String, Codable, Equatable, Sendable {
    case fast
    case smart
}

/// High-level category of a user request. This is the shared vocabulary the
/// deterministic router and the on-device model classifier both produce.
public enum RoutedIntent: String, Codable, Equatable, Sendable {
    /// Save/recall a memory ("remember that ...", "what do you remember").
    case memory
    /// Needs the web ("find ...", "latest news", "top 5 ...").
    case web
    /// Performs a side effect ("open ...", "send ...", "draft a message").
    case action
    /// Depends on what's on screen / in the browser ("summarize this page").
    case screenContext
    /// References a previous result set ("compare the first two").
    case compare
    /// Anything else — defer to a model for an actual answer.
    case general
}

/// Single source of truth for intent classification on the Swift side.
///
/// Before this type existed the same keyword/phrase tables were copied into
/// `BrainRoutePolicy`, `JarvisAppModel`, and (a near-identical set) the Python
/// brain. Centralizing them here removes the drift between those copies; the
/// brain now receives the decision instead of re-deriving it. See
/// `IntentClassifying` for the model-backed extension point that replaces the
/// brittle prefix matching for ambiguous phrasing.
public struct IntentRouter: Sendable {
    public init() {}

    /// Phrases that mean "the request is about what's currently on screen".
    /// This is the *only* copy of this list now — Swift sends the computed
    /// flag to the brain, which trusts it rather than keeping its own table.
    public static let screenContextPhrases: [String] = [
        "read this page",
        "read the page",
        "read this",
        "read that",
        "summarize this",
        "summarize the page",
        "summarize this page",
        "summarize this webpage",
        "summarize the webpage",
        "summarize this website",
        "summarize the website",
        "summarize this article",
        "summarize the article",
        "summarize this tab",
        "selected text",
        "highlighted text",
        "this selection",
        "the selection",
        "the highlighted",
        "what does this mean",
        "what's this mean",
        "what does that mean",
        "explain this",
        "explain that",
        "tell me about this",
        "tell me about that",
        "what is this",
        "what's this",
        "who is this",
        "who's this",
        "rewrite this",
        "translate this",
        "what am i looking at",
        "what is on my screen",
        "what's on my screen",
        "what is this page",
        "what's this page",
        "this tab",
        "this email",
        "this message",
        "this calendar",
        "on screen"
    ]

    /// User-facing phrases that mean "skip local answers and use the provider
    /// backed brain for this turn." "Clout" is accepted as a spoken/typed alias
    /// for the intended cloud-agent command.
    public static let cloudAgentPhrases: [String] = [
        "use cloud agent",
        "use the cloud agent",
        "use a cloud agent",
        "ask cloud agent",
        "ask the cloud agent",
        "cloud agent",
        "send this to cloud",
        "route this to cloud",
        "use clout agent",
        "use the clout agent",
        "use a clout agent",
        "ask clout agent",
        "ask the clout agent",
        "clout agent"
    ]

    public func requiresScreenContext(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        return Self.screenContextPhrases.contains { lower.contains($0) }
            || Self.isPageSummaryRequest(lower)
    }

    public func referencesSelectedOrHighlightedText(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        let phrases = [
            "selected text",
            "highlighted text",
            "highlighted",
            "selection",
            "this selection",
            "that selection",
            "what does this mean",
            "what's this mean",
            "what does that mean",
            "explain this",
            "explain that",
            "tell me about this",
            "tell me about that",
            "rewrite this",
            "translate this"
        ]
        return phrases.contains { lower.contains($0) }
    }

    public func prefersCloudAgent(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        return Self.cloudAgentPhrases.contains { lower.contains($0) }
    }

    public func isMemoryRequest(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        return lower.hasPrefix("remember ")
            || lower.hasPrefix("remember that ")
            || lower.hasPrefix("save this ")
            || lower.hasPrefix("don't forget ")
            || lower.hasPrefix("dont forget ")
            || lower.contains("what do you remember")
            || lower.contains("remember about")
            || lower.contains("delete memory")
            || lower.contains("clear memory")
    }

    public func isWebRequest(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        return lower.hasPrefix("find ")
            || lower.hasPrefix("search ")
            || lower.hasPrefix("look up ")
            || lower.contains(" search for ")
            || lower.contains(" on the web")
            || lower.contains(" on google")
            || lower.contains("latest ")
            || lower.contains("current ")
            || lower.contains("today's ")
            || lower.contains("news")
            || lower.contains("top 5")
            || lower.contains("top five")
            || lower.contains("places to buy")
            || lower.contains("where can i buy")
    }

    public func isActionRequest(_ transcript: String) -> Bool {
        let lower = normalized(transcript)
        return lower.hasPrefix("open ")
            || lower.hasPrefix("launch ")
            || lower.hasPrefix("click ")
            || lower.hasPrefix("send ")
            || lower.hasPrefix("email ")
            || lower.hasPrefix("text ")
            || lower.hasPrefix("message ")
            || lower.hasPrefix("draft ")
            || lower.hasPrefix("run command ")
            || lower.hasPrefix("run shell command ")
            || lower.contains(" send ")
            || lower.contains(" email ")
    }

    public func isCompareRequest(_ transcript: String) -> Bool {
        normalized(transcript).hasPrefix("compare ")
    }

    /// Deterministic classification. Order matters: the most specific /
    /// side-effecting intents win so we never answer an "open ..." with a
    /// chatty model reply.
    public func classify(_ transcript: String) -> RoutedIntent {
        if isMemoryRequest(transcript) { return .memory }
        if isActionRequest(transcript) { return .action }
        if isCompareRequest(transcript) { return .compare }
        if isWebRequest(transcript) { return .web }
        if requiresScreenContext(transcript) { return .screenContext }
        return .general
    }

    /// "fast" vs "smart" routing for the cloud brain. Unifies what used to be
    /// `JarvisAppModel.brainMode` and the Python `_task_type` heuristic.
    public func mode(for transcript: String, hasBrowserContext: Bool) -> BrainMode {
        let lower = normalized(transcript)
        if prefersCloudAgent(transcript) {
            return .smart
        }
        if Self.isPageSummaryRequest(lower) {
            return .fast
        }
        if lower.contains("compare")
            || lower.contains("analyze")
            || lower.contains("plan")
            || lower.contains("think through")
            || lower.contains("evaluate")
            || lower.contains("tradeoff") {
            return .smart
        }
        if hasBrowserContext,
           lower.contains("why") || lower.contains("how") || lower.contains("explain") {
            return .smart
        }
        return .fast
    }

    private func normalized(_ transcript: String) -> String {
        transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func isPageSummaryRequest(_ lower: String) -> Bool {
        guard lower.contains("summar") else { return false }
        let pageWords = ["page", "webpage", "website", "site", "article", "tab"]
        return pageWords.contains { lower.contains($0) }
    }
}

/// Extension point for replacing brittle prefix matching with a model that
/// understands paraphrase ("could you look that up", "I want you to remember").
///
/// `IntentRouter` is the synchronous, zero-latency default; `ModelIntentClassifier`
/// (in JarvisMac) layers an on-device model on top for the genuinely ambiguous
/// cases, falling back to the deterministic result on any failure.
public protocol IntentClassifying: Sendable {
    func classifyIntent(_ transcript: String) async -> RoutedIntent
}

extension IntentRouter: IntentClassifying {
    public func classifyIntent(_ transcript: String) async -> RoutedIntent {
        classify(transcript)
    }
}
