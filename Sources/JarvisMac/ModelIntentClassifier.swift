import Foundation
import FoundationModels
import JarvisCore

/// Intent classification that upgrades the deterministic `IntentRouter` with an
/// on-device model for ambiguous phrasing.
///
/// The deterministic router handles the clear, side-effecting cases instantly
/// (and is the only thing consulted for them, so commands like "open Spotify"
/// pay zero model latency). Only when the router can't tell — it returns
/// `.general` — does this ask Apple's on-device model to pick a category, which
/// catches paraphrases that prefix matching misses ("could you look that up for
/// me", "I'd like you to hold on to this"). Any unavailability or parse failure
/// falls back to `.general`, i.e. "let the brain handle it" — never a regression.
public struct ModelIntentClassifier: IntentClassifying {
    private let router: IntentRouter

    public init(router: IntentRouter = IntentRouter()) {
        self.router = router
    }

    public func classifyIntent(_ transcript: String) async -> RoutedIntent {
        let deterministic = router.classify(transcript)
        guard deterministic == .general else { return deterministic }
        return await modelClassification(of: transcript) ?? .general
    }

    private func modelClassification(of transcript: String) async -> RoutedIntent? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        // Not worth a model round-trip for a stray word.
        guard trimmed.split(whereSeparator: \.isWhitespace).count >= 2 else { return nil }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let instructions = """
        You label a user's request with exactly one word from this set:
        memory, web, action, screen, general.
        - memory: save or recall a personal fact or preference.
        - web: needs current or online information, or a search.
        - action: performs something on the Mac (open, send, draft, play, run).
        - screen: about what is currently on screen, the page, or the browser.
        - general: anything else, including questions you can answer directly.
        Reply with only the single label word, nothing else.
        """
        do {
            let session = LanguageModelSession(model: model, instructions: instructions)
            let options = GenerationOptions(temperature: 0.0, maximumResponseTokens: 5)
            let response = try await session.respond(to: "Request: \(trimmed)\nLabel:", options: options)
            return parse(response.content)
        } catch {
            return nil
        }
    }

    private func parse(_ raw: String) -> RoutedIntent? {
        let token = raw.lowercased()
        if token.contains("memory") { return .memory }
        if token.contains("web") { return .web }
        if token.contains("action") { return .action }
        if token.contains("screen") { return .screenContext }
        if token.contains("general") { return .general }
        return nil
    }
}
