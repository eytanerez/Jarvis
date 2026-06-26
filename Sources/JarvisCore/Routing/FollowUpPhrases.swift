import Foundation

/// Pure detection of "I'm done" replies during voice conversation turns.
///
/// Extracted from `JarvisAppModel` so it lives next to the rest of the routing
/// vocabulary and can be unit-tested without spinning up the whole app model.
public enum FollowUpPhrases {
    public static let donePhrases: Set<String> = [
        "all good",
        "all set",
        "alright thanks",
        "alright thank you",
        "appreciate it",
        "bye",
        "cool thanks",
        "done",
        "goodbye",
        "i am all good",
        "i am all set",
        "dont need it",
        "i am done",
        "i am done talking",
        "i am finished",
        "i am good",
        "i do not need anything",
        "i do not need anything else",
        "i do not want to chat",
        "i do not want to chat anymore",
        "i do not want to continue",
        "i do not want to talk",
        "i do not want to talk anymore",
        "i dont need anything",
        "i dont need anything else",
        "i dont need it",
        "i dont want to chat",
        "i dont want to chat anymore",
        "i dont want to continue",
        "i dont want to talk",
        "i dont want to talk anymore",
        "im all good",
        "im all set",
        "im done",
        "im done talking",
        "im finished",
        "im good",
        "much appreciated",
        "nah",
        "no",
        "no more",
        "no more questions",
        "no that is all",
        "no that is all thanks",
        "no thats all",
        "no thats all thanks",
        "no thank you",
        "no thanks",
        "nope",
        "not needed",
        "not right now",
        "nothing",
        "nothing else",
        "nothing for now",
        "ok thanks",
        "ok thank you",
        "okay thanks",
        "okay thank you",
        "stop",
        "stop listening",
        "thanks",
        "thanks a lot",
        "thank you",
        "thanks so much",
        "that fine",
        "that is all",
        "that is all thanks",
        "that is enough",
        "that is everything",
        "that is fine",
        "that is it",
        "that is ok",
        "that is okay",
        "that will do",
        "that will be all",
        "thatll do",
        "thatll be all",
        "thats all",
        "thats all thanks",
        "thats enough",
        "thats everything",
        "thats fine",
        "thats it",
        "thats ok",
        "thats okay",
        "thank you so much",
        "thank you very much",
        "we are good",
        "we are done",
        "were good",
        "were done"
    ]

    public static func isDone(_ text: String) -> Bool {
        donePhrases.contains(normalized(text))
    }

    public static func normalized(_ text: String) -> String {
        let lower = text.lowercased()
            .replacingOccurrences(of: "jarvis", with: "")
            .replacingOccurrences(of: "i'm", with: "im")
            .replacingOccurrences(of: "i’m", with: "im")
            .replacingOccurrences(of: "don't", with: "dont")
            .replacingOccurrences(of: "don’t", with: "dont")
            .replacingOccurrences(of: "that's", with: "thats")
            .replacingOccurrences(of: "that’s", with: "thats")
            .replacingOccurrences(of: "that'll", with: "thatll")
            .replacingOccurrences(of: "that’ll", with: "thatll")
            .replacingOccurrences(of: "we're", with: "were")
            .replacingOccurrences(of: "we’re", with: "were")
        return lower
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
