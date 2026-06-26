import Foundation

public struct ResponseTemplates: Sendable {
    public init() {}

    public func directCommandSpeech(for response: StructuredResponse) -> String? {
        guard response.metadata.route == "direct_command" else { return nil }
        let text = response.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let lower = text.lowercased()
        if lower.hasPrefix("opening ") {
            return text
        }
        if lower.contains("couldn't open") || lower.contains("invalid") {
            return text
        }
        if lower == "canceled." || lower == "paused." || lower == "skipping." || lower == "playing." || lower == "muted." {
            return text
        }
        return text
    }

    public func speakForOpenedResults(resultCount: Int, openedCount: Int) -> String {
        if openedCount <= 1 {
            return "I opened it."
        }
        if resultCount > 0 {
            return "I found \(min(resultCount, openedCount)) options and opened them."
        }
        return "I opened \(openedCount) links."
    }
}

