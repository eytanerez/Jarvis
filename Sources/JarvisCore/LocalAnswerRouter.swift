import Foundation

public enum LocalAnswerDecision: Equatable, Sendable {
    case answer(String)
    case escalate(String)
}

public struct LocalAnswerRouter: Sendable {
    public init() {}

    public func answer(_ transcript: String, context: ContextPacket? = nil) -> LocalAnswerDecision {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if let conversational = conversationalAnswer(lower) {
            return .answer(conversational)
        }

        if let percent = percentAnswer(lower) {
            return .answer(percent)
        }

        if let arithmetic = arithmeticAnswer(lower) {
            return .answer(arithmetic)
        }

        if lower == "what time is it" || lower == "what's the time" {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return .answer("It's \(formatter.string(from: Date())).")
        }

        if lower == "what is today" || lower == "what's today" || lower == "what date is it" {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            return .answer("Today is \(formatter.string(from: Date())).")
        }

        if lower == "what app am i in" || lower == "what app is this" {
            if let app = context?.activeApp?.appName ?? context?.frontmostApp ?? context?.accessibility?.frontmostApp {
                return .answer("You're in \(app).")
            }
            return .escalate("Frontmost app context is unavailable.")
        }

        if lower == "what document am i in" || lower == "what document is this" {
            if let title = context?.documentContext?.documentTitle, !title.isEmpty {
                return .answer("You're in \(title).")
            }
            return .escalate("Document context is unavailable.")
        }

        if lower == "summarize this selected text"
            || lower == "summarize selected text"
            || (lower.contains("summar") && lower.contains("selection")) {
            if let selected = context?.selectedText, !selected.isEmpty {
                return .answer(simpleSummary(selected))
            }
            return .escalate("No selected text is available.")
        }

        if lower.hasPrefix("define ") {
            return .escalate("Definitions should use the brain unless a local dictionary layer is added.")
        }

        if lower.contains("remember") || lower.contains("research") || lower.contains("web") || lower.contains("find ") {
            return .escalate("Requires memory, web, project context, or deeper reasoning.")
        }

        return .escalate("No local deterministic answer matched.")
    }

    private func conversationalAnswer(_ text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: #"[\?\!\.]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let greetings = ["hi", "hello", "hey", "hi jarvis", "hello jarvis", "hey jarvis"]
        if greetings.contains(cleaned) {
            return "Hey. I'm here."
        }

        let checkIns = [
            "how are you",
            "how are you doing",
            "how's it going",
            "hows it going",
            "you there",
            "are you there"
        ]
        if checkIns.contains(cleaned) {
            return "I'm good. Ready when you are."
        }

        let thanks = ["thanks", "thank you", "thanks jarvis", "thank you jarvis"]
        if thanks.contains(cleaned) {
            return "Anytime."
        }

        if cleaned == "who are you" || cleaned == "what are you" {
            return "I'm Jarvis, your Mac-side assistant. I can help with the app you're in, selected text, quick answers, and local actions."
        }

        if cleaned == "what can you do" || cleaned == "what can you help with" {
            return "I can help with selected text, the current page, quick questions, calendar context, and Mac actions when you ask."
        }

        return nil
    }

    private func percentAnswer(_ text: String) -> String? {
        let pattern = #"(?:(what'?s|what is)\s+)?([0-9]+(?:\.[0-9]+)?)\s*%\s+of\s+([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 4,
              let percentRange = Range(match.range(at: 2), in: text),
              let valueRange = Range(match.range(at: 3), in: text),
              let percent = Double(text[percentRange]),
              let value = Double(text[valueRange])
        else { return nil }

        let result = value * percent / 100
        return format(result)
    }

    private func arithmeticAnswer(_ text: String) -> String? {
        let sanitized = text
            .replacingOccurrences(of: "what's", with: "")
            .replacingOccurrences(of: "what is", with: "")
            .replacingOccurrences(of: "plus", with: "+")
            .replacingOccurrences(of: "minus", with: "-")
            .replacingOccurrences(of: "times", with: "*")
            .replacingOccurrences(of: "multiplied by", with: "*")
            .replacingOccurrences(of: "divided by", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard sanitized.range(of: #"^[0-9\.\+\-\*\/\(\)\s]+$"#, options: .regularExpression) != nil,
              sanitized.contains(where: { "+-*/".contains($0) })
        else { return nil }

        let expression = NSExpression(format: sanitized)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            return format(value.doubleValue)
        }
        return nil
    }

    private func simpleSummary(_ text: String) -> String {
        let normalized = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if normalized.count <= 220 {
            return normalized
        }
        let prefix = normalized.prefix(220)
        return "\(prefix)..."
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.4f", value).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }
}
