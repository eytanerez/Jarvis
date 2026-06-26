import Foundation

public enum FollowUpResolution: Equatable, Sendable {
    case action(AssistantAction, selected: StructuredResult?)
    case compare([StructuredResult])
    case needsBrain(String)
    case expired
    case notFollowUp
}

public struct FollowUpResolver: Sendable {
    public init() {}

    public func resolve(_ transcript: String, session: SessionStore) -> FollowUpResolution {
        if session.isExpired {
            return .expired
        }

        let text = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !session.lastResults.isEmpty || !session.lastOpenedURLs.isEmpty else {
            return .notFollowUp
        }

        if text.contains("compare") {
            let indexes = indexesMentioned(in: text)
            if indexes.count >= 2 {
                let selected = indexes.compactMap { result(atRank: $0, in: session.lastResults) }
                if selected.count >= 2 {
                    return .compare(selected)
                }
            }
            return .needsBrain("Comparison requires the previous result set.")
        }

        if text.contains("open") {
            if text.contains("again"), let url = session.lastOpenedURLs.last {
                return .action(AssistantAction(type: "open_url", payload: ["url": .string(url.absoluteString)]), selected: session.lastSelectedEntity)
            }

            if let result = findResult(in: text, results: session.lastResults), let url = result.url {
                return .action(AssistantAction(type: "open_url", payload: ["url": .string(url.absoluteString)]), selected: result)
            }
        }

        if text.contains("that") || text.contains("it") || text.contains("one") || text.contains("option") {
            if let result = findResult(in: text, results: session.lastResults) {
                return .needsBrain("Follow-up references \(result.name).")
            }
            return .needsBrain("Ambiguous follow-up requires brain routing.")
        }

        return .notFollowUp
    }

    private func findResult(in text: String, results: [StructuredResult]) -> StructuredResult? {
        if let named = results.first(where: { result in
            let name = result.name.lowercased()
            return text.contains(name) || name.split(separator: " ").contains { text.contains($0) }
        }) {
            return named
        }

        if let rank = indexesMentioned(in: text).first {
            return result(atRank: rank, in: results)
        }

        return nil
    }

    private func result(atRank rank: Int, in results: [StructuredResult]) -> StructuredResult? {
        results.first { $0.rank == rank } ?? results[safe: rank - 1]
    }

    private func indexesMentioned(in text: String) -> [Int] {
        var indexes: [Int] = []
        let words: [String: Int] = [
            "first": 1, "1st": 1, "one": 1, "number 1": 1,
            "second": 2, "2nd": 2, "two": 2, "number 2": 2,
            "third": 3, "3rd": 3, "three": 3, "number 3": 3,
            "fourth": 4, "4th": 4, "four": 4, "number 4": 4,
            "fifth": 5, "5th": 5, "five": 5, "number 5": 5
        ]

        for (word, index) in words where text.contains(word) {
            indexes.append(index)
        }

        if let regex = try? NSRegularExpression(pattern: #"\b([1-9])\b"#) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            indexes.append(contentsOf: matches.compactMap {
                Range($0.range(at: 1), in: text).flatMap { Int(text[$0]) }
            })
        }

        var seen = Set<Int>()
        return indexes.filter { seen.insert($0).inserted }.sorted()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
