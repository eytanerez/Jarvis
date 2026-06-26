import Foundation

public struct ComposedResponse: Sendable {
    public var response: StructuredResponse
    public var voiceStyle: VoiceStyle

    public init(response: StructuredResponse, voiceStyle: VoiceStyle) {
        self.response = response
        self.voiceStyle = voiceStyle
    }
}

public struct ResponseComposer: Sendable {
    private let templates = ResponseTemplates()

    public init() {}

    public func compose(
        response: StructuredResponse,
        userText: String,
        settings: AppSettings,
        executedActions: [StructuredResponse] = []
    ) -> ComposedResponse {
        var composed = response
        let mood = mood(for: composed, userText: userText, executedActions: executedActions)

        if let actionSpeech = actionSpeech(for: composed, executedActions: executedActions) {
            if composed.results.isEmpty {
                composed.answer = executedActions.last?.answer ?? composed.answer
            } else if !composed.answer.lowercased().contains("opened") {
                let openedCount = executedActions
                    .filter { $0.answer.lowercased().hasPrefix("opening ") }
                    .map { $0.metadata.actionCount ?? 0 }
                    .reduce(0, +)
                if openedCount > 0 {
                    composed.answer += "\n\nOpened \(openedCount) link\(openedCount == 1 ? "" : "s")."
                }
            }
            composed.speak = actionSpeech
        } else if let direct = templates.directCommandSpeech(for: composed) {
            composed.speak = direct
        }

        composed.answer = cleanVisualText(composed.answer)
        composed.speak = Self.sanitizeSpokenText(composed.speak.isEmpty ? composed.answer : composed.speak)
        composed.speak = clippedSpokenText(
            composed.speak,
            style: settings.personality.spokenStyle,
            limit: settings.voice.spokenSummaryLimit
        )
        composed.metadata.mood = mood.rawValue

        let style = VoiceStyle.style(for: mood, spokenLimit: settings.voice.spokenSummaryLimit)
        return ComposedResponse(response: composed, voiceStyle: style)
    }

    public static func sanitizeSpokenText(_ text: String) -> String {
        var result = text
        result = stripCodeBlocks(result)
        result = replaceURLs(in: result)
        result = result
            .replacingOccurrences(of: #"(?m)^\s{0,3}#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*\d+[\.\)]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "%", with: " percent")
            .replacingOccurrences(of: #"[\[\]\{\}\(\)]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[\*#>|~]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    private func actionSpeech(for response: StructuredResponse, executedActions: [StructuredResponse]) -> String? {
        guard !executedActions.isEmpty else { return nil }
        let openedCount = executedActions
            .filter { $0.answer.lowercased().hasPrefix("opening ") }
            .map { $0.metadata.actionCount ?? 0 }
            .reduce(0, +)

        if openedCount > 0 {
            return templates.speakForOpenedResults(resultCount: response.results.count, openedCount: openedCount)
        }

        if response.metadata.route == "direct_command" {
            return executedActions.last?.speak
        }
        return nil
    }

    private func mood(for response: StructuredResponse, userText: String, executedActions: [StructuredResponse]) -> AssistantMood {
        let route = response.metadata.route ?? ""
        let answer = "\(response.answer) \(response.speak)".lowercased()
        let lowerUser = userText.lowercased()

        if response.requiresConfirmation || response.confirmation != nil {
            return .serious
        }
        if answer.contains("couldn't") || answer.contains("can’t") || answer.contains("cannot") || answer.contains("failed") {
            return .careful
        }
        if answer.contains("invalid") || answer.contains("not available") || answer.contains("missing") {
            return .confused
        }
        if route == "direct_command" || !executedActions.isEmpty {
            return .quick
        }
        if route == "web_search" || lowerUser.contains("find ") || lowerUser.contains("search ") || lowerUser.contains("look up ") {
            return response.results.isEmpty ? .focused : .excited
        }
        if route == "context_missing" {
            return .careful
        }
        if route == "memory" {
            return .playful
        }
        if lowerUser.contains("dangerous") || lowerUser.contains("sudo") {
            return .serious
        }
        return .neutral
    }

    private func cleanVisualText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clippedSpokenText(_ text: String, style: SpokenStyle, limit: Int) -> String {
        let adjustedLimit: Int
        switch style {
        case .veryShort:
            adjustedLimit = min(limit, 140)
        case .naturalShort:
            adjustedLimit = limit
        case .detailed:
            adjustedLimit = max(limit, 420)
        }
        guard text.count > adjustedLimit else { return text }
        let clipped = String(text.prefix(adjustedLimit))
        if let sentenceEnd = clipped.lastIndex(where: { ".!?".contains($0) }) {
            return String(clipped[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripCodeBlocks(_ text: String) -> String {
        text.replacingOccurrences(of: #"```[\s\S]*?```"#, with: " ", options: .regularExpression)
    }

    private static func replaceURLs(in text: String) -> String {
        let pattern = #"(?i)\b((?:https?://)?(?:www\.)?[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+(?:/[^\s]*)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text
        for match in matches {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let raw = String(result[range])
            result.replaceSubrange(range, with: spokenSiteName(from: raw))
        }
        return result
    }

    private static func spokenSiteName(from raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: #"^https?://"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^www\."#, with: "", options: [.regularExpression, .caseInsensitive])
        let host = cleaned.split(separator: "/").first.map(String.init) ?? cleaned
        let labels = host.split(separator: ".").map(String.init)
        guard let first = labels.first else { return "that site" }
        let known: [String: String] = [
            "amazon": "Amazon",
            "apple": "Apple",
            "bestbuy": "Best Buy",
            "costco": "Costco",
            "google": "Google",
            "gmail": "Gmail",
            "youtube": "YouTube",
            "github": "GitHub",
            "chatgpt": "ChatGPT",
            "openai": "OpenAI",
            "perplexity": "Perplexity"
        ]
        return "on \(known[first.lowercased()] ?? first.replacingOccurrences(of: "-", with: " ").capitalized)"
    }
}
