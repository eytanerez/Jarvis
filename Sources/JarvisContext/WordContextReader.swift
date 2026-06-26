import Foundation
import JarvisCore

public struct WordContextReader: Sendable {
    private static let fieldMarker = "\n---JARVIS_WORD_FIELD---\n"
    private static let textLimit = 24_000

    public init() {}

    public func readWordContext(target: TargetAppSnapshot?, selectedTextFallback: String? = nil) -> DocumentContextReadResult {
        let appName = target?.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordAppName = (appName?.isEmpty == false) ? appName! : "Microsoft Word"
        let output = runWordScript(appName: wordAppName)
        switch output {
        case .failure(let warning):
            return DocumentContextReadResult(context: nil, warnings: [warning])
        case .success(let fields):
            let documentPath = normalizedPath(fields.documentPath)
            let fileExtension = documentPath.flatMap { URL(fileURLWithPath: $0).pathExtension.lowercased().nilIfEmpty }
            let docxText = documentPath
                .flatMap { path in fileExtension == "docx" ? readDocxText(at: URL(fileURLWithPath: path)) : nil }
            let selected = fields.selectedText.nilIfBlank ?? selectedTextFallback?.nilIfBlank
            let preview = docxText?.nilIfBlank ?? fields.currentParagraph.nilIfBlank
            let context = DocumentContext(
                appName: wordAppName,
                documentTitle: fields.documentName.nilIfBlank,
                documentPath: documentPath,
                fileExtension: fileExtension,
                selectedText: selected,
                currentParagraph: fields.currentParagraph.nilIfBlank,
                previousParagraph: fields.previousParagraph.nilIfBlank,
                nextParagraph: fields.nextParagraph.nilIfBlank,
                textPreview: preview?.truncated(to: Self.textLimit),
                textLength: docxText?.count ?? preview?.count ?? 0,
                source: "microsoft_word",
                capturedAt: Date()
            )
            return DocumentContextReadResult(context: context, warnings: [])
        }
    }

    private func runWordScript(appName: String) -> Result<WordFields, ContextWarning> {
        let marker = Self.fieldMarker
        let script = """
        tell application "\(escapeForAppleScript(appName))"
          if (count of documents) is 0 then return "__JARVIS_NO_DOCUMENT__"
          set docName to ""
          set docPath to ""
          set selectedText to ""
          set currentParagraph to ""
          set previousParagraph to ""
          set nextParagraph to ""
          try
            set docName to name of active document
          end try
          try
            set docPath to POSIX path of (path of active document as alias)
          end try
          try
            set selectedText to content of selection
          end try
          try
            set currentParagraph to content of paragraph 1 of selection
          end try
          try
            set paragraphIndex to index of paragraph 1 of selection
            if paragraphIndex > 1 then set previousParagraph to content of paragraph (paragraphIndex - 1) of active document
            if paragraphIndex < (count of paragraphs of active document) then set nextParagraph to content of paragraph (paragraphIndex + 1) of active document
          end try
          return docName & "\(marker)" & docPath & "\(marker)" & selectedText & "\(marker)" & currentParagraph & "\(marker)" & previousParagraph & "\(marker)" & nextParagraph
        end tell
        """

        var errorInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(ContextWarning(code: "word_script_create_failed", message: "Could not create the Microsoft Word context script.", source: "word"))
        }
        let descriptor = appleScript.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return .failure(wordWarning(from: errorInfo))
        }
        let output = descriptor.stringValue ?? ""
        if output == "__JARVIS_NO_DOCUMENT__" {
            return .failure(ContextWarning(code: "word_no_document", message: "I captured Microsoft Word, but no document is open.", source: "word"))
        }
        let parts = output.components(separatedBy: marker)
        guard parts.count >= 6 else {
            return .failure(ContextWarning(code: "word_unexpected_output", message: "Microsoft Word returned document context in an unexpected format.", source: "word"))
        }
        return .success(
            WordFields(
                documentName: parts[0],
                documentPath: parts[1],
                selectedText: parts[2],
                currentParagraph: parts[3],
                previousParagraph: parts[4],
                nextParagraph: parts[5]
            )
        )
    }

    private func wordWarning(from errorInfo: NSDictionary) -> ContextWarning {
        let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Microsoft Word context failed."
        let lower = message.lowercased()
        if number == -1743 || lower.contains("not authorized") || lower.contains("not authorised") || lower.contains("not allowed") {
            return ContextWarning(
                code: "word_automation_denied",
                message: "I can't read Microsoft Word yet. Give Jarvis Automation and Accessibility permission, or select the sentence and try again.",
                source: "word"
            )
        }
        return ContextWarning(code: "word_script_failed", message: "Microsoft Word context failed: \(message)", source: "word")
    }

    private func readDocxText(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let script = """
        import sys, zipfile, xml.etree.ElementTree as ET
        path = sys.argv[1]
        ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
        parts = []
        with zipfile.ZipFile(path) as archive:
            xml = archive.read('word/document.xml')
        root = ET.fromstring(xml)
        for paragraph in root.findall('.//w:p', ns):
            texts = [node.text or '' for node in paragraph.findall('.//w:t', ns)]
            text = ''.join(texts).strip()
            if text:
                parts.append(text)
        print('\\n'.join(parts)[:\(Self.textLimit)])
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", script, url.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.nilIfBlank
    }

    private func normalizedPath(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private struct WordFields: Equatable {
        var documentName: String
        var documentPath: String
        var selectedText: String
        var currentParagraph: String
        var previousParagraph: String
        var nextParagraph: String
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func truncated(to limit: Int) -> String {
        count > limit ? String(prefix(limit)) : self
    }
}
