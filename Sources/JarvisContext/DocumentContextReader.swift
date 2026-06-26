import Foundation
import JarvisCore

public struct DocumentContextReadResult: Equatable, Sendable {
    public var context: DocumentContext?
    public var warnings: [ContextWarning]

    public init(context: DocumentContext? = nil, warnings: [ContextWarning] = []) {
        self.context = context
        self.warnings = warnings
    }
}

public struct DocumentContextReader: Sendable {
    private let wordReader: WordContextReader

    public init(wordReader: WordContextReader = WordContextReader()) {
        self.wordReader = wordReader
    }

    public func readDocumentContext(
        target: TargetAppSnapshot?,
        selectedText: String?,
        settings: ContextSettings = ContextSettings()
    ) -> DocumentContextReadResult {
        guard settings.wordContextEnabled else {
            return DocumentContextReadResult()
        }
        guard isMicrosoftWord(target) else {
            return DocumentContextReadResult()
        }
        return wordReader.readWordContext(target: target, selectedTextFallback: selectedText)
    }

    private func isMicrosoftWord(_ target: TargetAppSnapshot?) -> Bool {
        let haystack = "\(target?.appName ?? "") \(target?.bundleIdentifier ?? "")".lowercased()
        return haystack.contains("microsoft word") || haystack.contains("com.microsoft.word")
    }
}
