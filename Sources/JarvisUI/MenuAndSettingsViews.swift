import AppKit
import Foundation
import JarvisCore
import JarvisMac
import SwiftUI

public struct JarvisMenuView: View {
    @ObservedObject var model: JarvisAppModel
    @Environment(\.openWindow) private var openWindow
    @State private var openAtLogin = LoginItemManager().isEnabled
    private let loginItem = LoginItemManager()

    public init(model: JarvisAppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.brainReady ? "Brain ready" : "Brain reconnecting")
                .foregroundStyle(model.brainReady ? .green : .orange)
            Button("Talk") { model.toggleFromHotkey() }
            Button("Debug Window") { openWindow(id: "debug") }
            SettingsLink()
            Toggle("Open at Login", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, newValue in
                    loginItem.setEnabled(newValue)
                }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }
}

public struct DebugView: View {
    @ObservedObject var model: JarvisAppModel

    public init(model: JarvisAppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(model.phase.title, systemImage: "sparkles")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button("Talk") { model.toggleFromHotkey() }
                }
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Status").foregroundStyle(.secondary)
                    Text(model.statusLine)
                }
                GridRow {
                    Text("Turn").foregroundStyle(.secondary)
                    Text(model.activeTurn?.status.rawValue ?? "none")
                }
                GridRow {
                    Text("Brain").foregroundStyle(.secondary)
                    Text(model.brainReady ? "Ready" : "Reconnecting")
                }
                GridRow {
                    Text("Captured app").foregroundStyle(.secondary)
                    Text(model.session.targetAppSnapshot?.appName ?? "None")
                }
                GridRow {
                    Text("Active app").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.activeApp?.appName ?? "None")
                }
                GridRow {
                    Text("Captured window title").foregroundStyle(.secondary)
                    Text(model.session.targetAppSnapshot?.windowTitle ?? "None")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Context frontmost").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.frontmostApp ?? "Unknown")
                }
                GridRow {
                    Text("Browser detected").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.browser?.browser ?? "None")
                }
                GridRow {
                    Text("Browser title").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.browser?.title ?? "None")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Browser URL").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.browser?.url?.absoluteString ?? "None")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Selected text length").foregroundStyle(.secondary)
                    Text("\((model.session.lastScreenContext?.selectedText ?? model.session.lastScreenContext?.browser?.selectedText ?? "").count)")
                }
                GridRow {
                    Text("Surrounding text length").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.surroundingText?.count ?? 0) characters")
                }
                GridRow {
                    Text("Document title").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.documentContext?.documentTitle ?? "None")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Document path").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.documentContext?.documentPath ?? "None")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Document text length").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.documentContext?.textLength ?? 0) characters")
                }
                GridRow {
                    Text("Word paragraph context").foregroundStyle(.secondary)
                    Text(wordParagraphSummary)
                }
                GridRow {
                    Text("Page text length").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.browser?.pageText?.count ?? 0) characters")
                }
                GridRow {
                    Text("AX visible text length").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.accessibility?.visibleText?.count ?? 0) characters")
                }
                GridRow {
                    Text("Schedule events").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.schedule?.events.count ?? 0)")
                }
                GridRow {
                    Text("Schedule reminders").foregroundStyle(.secondary)
                    Text("\(model.session.lastScreenContext?.schedule?.reminders.count ?? 0)")
                }
                GridRow {
                    Text("Relevant file snippets").foregroundStyle(.secondary)
                    Text(relevantFilesText)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Relevant memories").foregroundStyle(.secondary)
                    Text(relevantMemoriesText)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Screenshot fallback available").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.screenshotFallbackAvailable == true ? "Yes" : "No")
                }
                GridRow {
                    Text("Context warnings").foregroundStyle(.secondary)
                    Text(contextWarningsText)
                        .foregroundStyle(contextWarningsText == "None" ? Color.primary : Color.orange)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Last context error").foregroundStyle(.secondary)
                    Text(model.session.lastScreenContext?.browserError?.message ?? "None")
                        .foregroundStyle(model.session.lastScreenContext?.browserError == nil ? Color.primary : Color.orange)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Route").foregroundStyle(.secondary)
                    Text(lastMetadata.route ?? "Unknown")
                }
                GridRow {
                    Text("Provider").foregroundStyle(.secondary)
                    Text(lastMetadata.provider ?? "None")
                }
                GridRow {
                    Text("Model").foregroundStyle(.secondary)
                    Text(lastMetadata.model ?? model.session.lastStructuredResponse?.modelUsed ?? "None")
                }
                GridRow {
                    Text("Used LLM").foregroundStyle(.secondary)
                    Text((lastMetadata.provider != nil || lastMetadata.model != nil || model.session.lastStructuredResponse?.modelUsed != nil) ? "Yes" : "No")
                }
                GridRow {
                    Text("Used memory").foregroundStyle(.secondary)
                    Text(lastMetadata.usedMemory ? "Yes" : "No")
                }
                GridRow {
                    Text("Used web").foregroundStyle(.secondary)
                    Text(lastMetadata.usedWeb ? "Yes" : "No")
                }
                GridRow {
                    Text("Used screen context").foregroundStyle(.secondary)
                    Text(lastMetadata.usedScreenContext ? "Yes" : "No")
                }
                GridRow {
                    Text("Context available").foregroundStyle(.secondary)
                    Text(lastMetadata.contextAvailable ? "Yes" : "No")
                }
                GridRow {
                    Text("Memory").foregroundStyle(.secondary)
                    Text(memoryStatusText)
                }
                GridRow {
                    Text("Active provider").foregroundStyle(.secondary)
                    Text(activeMemoryProviderText)
                }
                GridRow {
                    Text("Gemini key configured").foregroundStyle(.secondary)
                    Text(yesNo(model.providerKeyPresence[.gemini] == true))
                }
                GridRow {
                    Text("Brain received Gemini key").foregroundStyle(.secondary)
                    Text(yesNo(model.memoryStatus?.brainReceivedGeminiKey == true))
                }
                GridRow {
                    Text("Memory backend").foregroundStyle(.secondary)
                    Text(model.memoryStatus?.memoryBackend ?? memoryStatusText)
                }
                GridRow {
                    Text("Fallback reason").foregroundStyle(.secondary)
                    Text(memoryFallbackReasonText)
                        .foregroundStyle(memoryFallbackReasonText == "None" ? Color.primary : Color.orange)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("TTS").foregroundStyle(.secondary)
                    Text(ttsStatusText)
                }
                GridRow {
                    Text("File index").foregroundStyle(.secondary)
                    Text(fileIndexStatusText)
                }
                GridRow {
                    Text("Session").foregroundStyle(.secondary)
                    Text(model.session.currentConversationId)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Last transcript").foregroundStyle(.secondary)
                    Text(model.lastTranscript.isEmpty ? "None" : model.lastTranscript)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Warnings").foregroundStyle(.secondary)
                    Text(warningsText)
                        .foregroundStyle(warningsText == "None" ? Color.primary : Color.orange)
                        .textSelection(.enabled)
                }
            }
            if !model.ttsDebugLog.isEmpty {
                Divider()
                Text("TTS Playback")
                    .font(.headline)
                ForEach(Array(model.ttsDebugLog.suffix(6).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !model.session.lastResults.isEmpty {
                List(model.session.lastResults) { result in
                    VStack(alignment: .leading) {
                        Text(result.name)
                        Text(result.url?.absoluteString ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let attempts = model.providerDiagnostics?.attempts, !attempts.isEmpty {
                Divider()
                Text("Provider Attempts")
                    .font(.headline)
                ForEach(attempts.suffix(5)) { attempt in
                    HStack {
                        Text(attempt.provider.capitalized)
                            .font(.body.weight(.medium))
                        Text(attempt.taskType)
                            .foregroundStyle(.secondary)
                        Text(attempt.model ?? "")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(attempt.ok ? "OK" : attempt.message)
                            .foregroundStyle(attempt.ok ? .green : .red)
                            .lineLimit(1)
                    }
                }
            }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    private var memoryStatusText: String {
        guard let status = model.memoryStatus else { return "Unknown" }
        let backend = status.memoryBackend ?? (status.activeProvider == "mem0" ? "mem0 active" : "JSON fallback")
        if status.activeProvider == "mem0" {
            return backend
        }
        let reason = status.fallbackReason ?? status.lastError
        return "\(backend) (\(status.fallbackCount))\(reason.map { ": \($0)" } ?? "")"
    }

    private var activeMemoryProviderText: String {
        if let displayName = model.memoryStatus?.activeModelProviderDisplayName {
            return displayName
        }
        return providerDisplayName(model.memoryStatus?.activeModelProvider)
    }

    private var memoryFallbackReasonText: String {
        guard model.memoryStatus?.activeProvider != "mem0" else { return "None" }
        return model.memoryStatus?.fallbackReason ?? model.memoryStatus?.lastError ?? "None"
    }

    private var ttsStatusText: String {
        guard let status = model.ttsStatus else { return "Unknown" }
        let kokoro = status.importable
            ? "Kokoro ready: model \(status.modelPresent ? "yes" : "no"), voices \(status.voicesPresent ? "yes" : "no")"
            : (status.lastError ?? "Kokoro unavailable")
        let chatterbox = status.chatterboxImportable == true
            ? "Chatterbox ready on \(status.chatterboxDevice ?? "auto")"
            : "Chatterbox not installed"
        return "\(kokoro). \(chatterbox)."
    }

    private var lastMetadata: ResponseMetadata {
        model.session.lastStructuredResponse?.metadata ?? ResponseMetadata()
    }

    private var warningsText: String {
        let contextWarnings = model.session.lastScreenContext?.warnings.map { warning in
            warning.source.map { "\($0): \(warning.message)" } ?? warning.message
        } ?? []
        let warnings = model.turnWarnings + lastMetadata.warnings + contextWarnings
        guard !warnings.isEmpty else { return "None" }
        return Array(NSOrderedSet(array: warnings).compactMap { $0 as? String }).joined(separator: "\n")
    }

    private var wordParagraphSummary: String {
        guard let document = model.session.lastScreenContext?.documentContext else { return "None" }
        let selected = document.selectedText?.isEmpty == false ? "selected" : nil
        let current = document.currentParagraph?.isEmpty == false ? "current" : nil
        let previous = document.previousParagraph?.isEmpty == false ? "previous" : nil
        let next = document.nextParagraph?.isEmpty == false ? "next" : nil
        let pieces = [selected, previous, current, next].compactMap { $0 }
        return pieces.isEmpty ? "No readable paragraph text" : pieces.joined(separator: ", ")
    }

    private var relevantFilesText: String {
        let files = model.session.lastScreenContext?.relevantFiles ?? []
        guard !files.isEmpty else { return "None" }
        return files.prefix(8).map { file in
            let score = file.score.map { String(format: " %.2f", $0) } ?? ""
            return "\(file.filename)\(score)\n\(file.path)"
        }.joined(separator: "\n\n")
    }

    private var relevantMemoriesText: String {
        let memories = model.session.lastScreenContext?.relevantMemories ?? []
        guard !memories.isEmpty else { return "None" }
        return memories.prefix(8).map { memory in
            if let category = memory.category, !category.isEmpty {
                return "[\(category)] \(memory.text)"
            }
            return memory.text
        }.joined(separator: "\n")
    }

    private var contextWarningsText: String {
        let warnings = model.session.lastScreenContext?.warnings.map(\.message) ?? []
        guard !warnings.isEmpty else { return "None" }
        return warnings.joined(separator: "\n")
    }

    private var fileIndexStatusText: String {
        guard let status = model.fileIndexStatus else { return "Unknown" }
        let last = status.lastIndexTime.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "never"
        return "\(status.fileCount) files, last index \(last), watching \(yesNo(status.watching))"
    }

    private func providerDisplayName(_ provider: String?) -> String {
        guard let provider else { return "None" }
        return ProviderID(rawValue: provider)?.displayName ?? provider.capitalized
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

public struct JarvisSettingsView: View {
    @ObservedObject var model: JarvisAppModel
    private let embedded: Bool
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var geminiKey = ""
    @State private var shortcutName = ""
    @State private var shortcutURL = ""
    @State private var exclusionPattern = ""

    public init(model: JarvisAppModel, embedded: Bool = false) {
        self.model = model
        self.embedded = embedded
    }

    public var body: some View {
        TabView {
            providers
                .tabItem { Label("Providers", systemImage: "key") }
            shortcuts
                .tabItem { Label("Shortcuts", systemImage: "link") }
            contextSettings
                .tabItem { Label("Context", systemImage: "scope") }
            privacy
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            voiceSession
                .tabItem { Label("Voice", systemImage: "speaker.wave.2") }
        }
        .padding(20)
        .frame(
            minWidth: embedded ? nil : 780,
            idealWidth: embedded ? nil : 860,
            maxWidth: embedded ? .infinity : nil,
            minHeight: embedded ? nil : 620,
            idealHeight: embedded ? nil : 680,
            maxHeight: embedded ? .infinity : nil,
            alignment: .topLeading
        )
    }

    private var providers: some View {
        SettingsScrollPage {
            ForEach($model.settings.providers) { $provider in
                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        GridRow {
                            Text("Enabled")
                            Toggle("", isOn: $provider.enabled)
                                .labelsHidden()
                        }
                        GridRow {
                            Text("Fast model")
                            TextField("Model", text: $provider.fastModel)
                                .textFieldStyle(.roundedBorder)
                        }
                        GridRow {
                            Text("Smart model")
                            TextField("Model", text: $provider.smartModel)
                                .textFieldStyle(.roundedBorder)
                        }
                        GridRow {
                            Text("API key")
                            HStack {
                                SecureField(keyPlaceholder(for: provider.id), text: keyBinding(for: provider.id))
                                    .textFieldStyle(.roundedBorder)
                                Text(model.providerKeyPresence[provider.id] == true ? "Saved" : "Not saved")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(model.providerKeyPresence[provider.id] == true ? .green : .secondary)
                                    .frame(width: 70, alignment: .leading)
                                Button(model.providerKeyPresence[provider.id] == true ? "Replace" : "Save") {
                                    model.saveAPIKey(keyBinding(for: provider.id).wrappedValue, for: provider.id)
                                    keyBinding(for: provider.id).wrappedValue = ""
                                }
                                Button("Remove") {
                                    model.removeAPIKey(for: provider.id)
                                    keyBinding(for: provider.id).wrappedValue = ""
                                }
                                .disabled(model.providerKeyPresence[provider.id] != true)
                            }
                        }
                    }
                } label: {
                    Label(provider.id.displayName, systemImage: provider.enabled ? "checkmark.circle.fill" : "circle")
                }
            }
            GroupBox {
                Picker("Web search mode", selection: $model.settings.webSearch.mode) {
                    ForEach(WebSearchMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            } label: {
                Label("Web Search", systemImage: "magnifyingglass")
            }
            HStack {
                Button("Save Provider Settings") { model.saveSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Test Providers") { model.testProviders() }
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcuts: some View {
        SettingsScrollPage {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Name")
                        TextField("Calibre dev", text: $shortcutName)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("URL")
                        TextField("https://example.com", text: $shortcutURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                HStack {
                    Button("Add Shortcut") { addShortcut() }
                        .disabled(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || URL(string: shortcutURL) == nil)
                    Text("Saved shortcuts work with commands like “Open Calibre dev.”")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } label: {
                Label("Add Shortcut", systemImage: "plus.circle")
            }

            GroupBox {
                if model.settings.shortcuts.isEmpty {
                    Text("No shortcuts yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(model.settings.shortcuts) { shortcut in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(shortcut.name)
                                .font(.body.weight(.medium))
                            Text(shortcut.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            model.settings.shortcuts.removeAll { $0.id == shortcut.id }
                            model.saveSettings()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .labelStyle(.iconOnly)
                        .help("Remove shortcut")
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            } label: {
                Label("Saved Shortcuts", systemImage: "link")
            }
        }
    }

    private var privacy: some View {
        SettingsScrollPage {
            GroupBox {
                Toggle("Enable memory", isOn: $model.settings.memory.enabled)
                Toggle("Explicit only", isOn: $model.settings.memory.explicitOnly)
                Toggle("Pause memory", isOn: $model.settings.memory.paused)
                Toggle("Suggested memories", isOn: $model.settings.memory.suggestedMemoriesEnabled)
                if let memoryStatus = model.memoryStatus {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        GridRow {
                            Text("Active provider").foregroundStyle(.secondary)
                            Text(memoryStatus.activeModelProviderDisplayName ?? settingsProviderDisplayName(memoryStatus.activeModelProvider))
                        }
                        GridRow {
                            Text("Gemini key configured").foregroundStyle(.secondary)
                            Text(settingsYesNo(model.providerKeyPresence[.gemini] == true))
                        }
                        GridRow {
                            Text("Brain received Gemini key").foregroundStyle(.secondary)
                            Text(settingsYesNo(memoryStatus.brainReceivedGeminiKey == true))
                        }
                        GridRow {
                            Text("Memory backend").foregroundStyle(.secondary)
                            Text(memoryStatus.memoryBackend ?? (memoryStatus.activeProvider == "mem0" ? "mem0 active" : "JSON fallback"))
                        }
                        GridRow {
                            Text("Fallback reason").foregroundStyle(.secondary)
                            Text(memoryStatus.activeProvider == "mem0" ? "None" : (memoryStatus.fallbackReason ?? memoryStatus.lastError ?? "None"))
                                .font(.caption)
                                .foregroundStyle(memoryStatus.activeProvider == "mem0" ? Color.primary : Color.orange)
                                .textSelection(.enabled)
                        }
                    }
                }
            } label: {
                Label("Memory", systemImage: "brain")
            }

            GroupBox {
                PermissionRow(name: "Microphone", detail: "Used when you ask Jarvis to listen.")
                PermissionRow(name: "Accessibility", detail: "Used when you ask about the current app or selected text.")
                PermissionRow(name: "Automation", detail: "Used for browser context and Spotify commands.")
                PermissionRow(name: "Screen Recording", detail: "Reserved for visual fallback when text is unavailable.")
            } label: {
                Label("Permissions", systemImage: "hand.raised")
            }

            Button("Save Privacy Settings") { model.saveSettings() }
        }
    }

    private var contextSettings: some View {
        SettingsScrollPage {
            GroupBox {
                Picker("Privacy level", selection: $model.settings.context.privacyLevel) {
                    ForEach(ContextPrivacyLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Toggle("Active app context", isOn: $model.settings.context.activeAppContextEnabled)
                Toggle("Selected text access", isOn: $model.settings.context.selectedTextAccessEnabled)
                Toggle("Accessibility access", isOn: $model.settings.context.accessibilityAccessEnabled)
                Toggle("Browser reader access", isOn: $model.settings.context.browserReaderEnabled)
                Toggle("Microsoft Word context", isOn: $model.settings.context.wordContextEnabled)
            } label: {
                Label("Active App Context", systemImage: "macwindow")
            }

            GroupBox {
                Toggle("File index enabled", isOn: $model.settings.context.fileIndexEnabled)
                if model.settings.context.approvedFolders.isEmpty {
                    Text("No approved folders.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.settings.context.approvedFolders, id: \.self) { folder in
                    HStack(alignment: .firstTextBaseline) {
                        Text(folder)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            model.settings.context.approvedFolders.removeAll { $0 == folder }
                            model.saveSettings()
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .labelStyle(.iconOnly)
                        .help("Remove folder")
                    }
                }
                HStack {
                    Button {
                        addContextFolder()
                    } label: {
                        Label("Add folder", systemImage: "plus.circle")
                    }
                    Button("Start") { model.startFileIndex() }
                    Button("Stop") { model.stopFileIndex() }
                    Button("Reindex") { model.reindexFileIndex() }
                    Button("Refresh") { model.refreshFileIndexStatus() }
                }
                if let status = model.fileIndexStatus {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        GridRow {
                            Text("Indexed folders").foregroundStyle(.secondary)
                            Text("\(status.indexedFolders.count)")
                        }
                        GridRow {
                            Text("File count").foregroundStyle(.secondary)
                            Text("\(status.fileCount)")
                        }
                        GridRow {
                            Text("Currently indexing").foregroundStyle(.secondary)
                            Text(settingsYesNo(status.currentlyIndexing))
                        }
                        GridRow {
                            Text("Watching").foregroundStyle(.secondary)
                            Text(settingsYesNo(status.watching))
                        }
                        GridRow {
                            Text("Failed files").foregroundStyle(.secondary)
                            Text("\(status.failedFiles.count)")
                        }
                        GridRow {
                            Text("Storage size").foregroundStyle(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(status.storageSize), countStyle: .file))
                        }
                        GridRow {
                            Text("Embedding backend").foregroundStyle(.secondary)
                            Text(status.embeddingBackend)
                        }
                    }
                }
            } label: {
                Label("File Access", systemImage: "folder")
            }

            GroupBox {
                HStack {
                    TextField("Pattern", text: $exclusionPattern)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") { addExclusion() }
                        .disabled(exclusionPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.settings.context.exclusions, id: \.self) { pattern in
                    HStack {
                        Text(pattern)
                            .font(.body.monospaced())
                        Spacer()
                        Button {
                            model.settings.context.exclusions.removeAll { $0 == pattern }
                            model.saveSettings()
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .labelStyle(.iconOnly)
                        .help("Remove exclusion")
                    }
                }
            } label: {
                Label("Exclusions", systemImage: "line.3.horizontal.decrease.circle")
            }

            GroupBox {
                Toggle("Memory context", isOn: $model.settings.context.memoryContextEnabled)
                Toggle("Never send file contents to cloud without permission", isOn: Binding(
                    get: { !model.settings.context.allowCloudFileContents },
                    set: { model.settings.context.allowCloudFileContents = !$0 }
                ))
                Toggle("Allow cloud summaries for approved folders", isOn: $model.settings.context.allowCloudFileContents)
                Toggle("Local-only mode", isOn: $model.settings.context.localOnlyMode)
            } label: {
                Label("Privacy", systemImage: "lock")
            }

            HStack {
                Button("Save Context Settings") { model.saveSettings() }
                    .keyboardShortcut(.defaultAction)
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var voiceSession: some View {
        SettingsScrollPage {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Name")
                        TextField("Jarvis", text: $model.settings.personality.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Tone")
                        Picker("Tone", selection: $model.settings.personality.tone) {
                            ForEach(ToneStyle.allCases) { tone in
                                Text(tone.displayName).tag(tone)
                            }
                        }
                    }
                    GridRow {
                        Text("Verbosity")
                        Picker("Verbosity", selection: $model.settings.personality.verbosity) {
                            ForEach(VerbosityLevel.allCases) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                    }
                    GridRow {
                        Text("Humor")
                        Picker("Humor", selection: $model.settings.personality.humor) {
                            ForEach(HumorLevel.allCases) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                    }
                    GridRow {
                        Text("Spoken length")
                        Picker("Spoken length", selection: $model.settings.personality.spokenStyle) {
                            ForEach(SpokenStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                    }
                    GridRow {
                        Text("Variation")
                        Toggle("Vary command responses", isOn: $model.settings.personality.variedCommandResponses)
                    }
                }
            } label: {
                Label("Personality", systemImage: "sparkles")
            }

            GroupBox {
                Picker("TTS engine", selection: $model.settings.voice.ttsEngine) {
                    ForEach(TTSEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                TextField("Kokoro voice", text: $model.settings.voice.kokoroVoice)
                    .textFieldStyle(.roundedBorder)
                Slider(value: $model.settings.voice.kokoroSpeed, in: 0.5...1.8, step: 0.05) {
                    Text("Kokoro speed")
                } minimumValueLabel: {
                    Text("0.5")
                } maximumValueLabel: {
                    Text("1.8")
                }
                Text("Kokoro speed: \(model.settings.voice.kokoroSpeed, specifier: "%.2f")")
                    .foregroundStyle(.secondary)
                Divider()
                TextField("Chatterbox reference audio path", text: $model.settings.voice.chatterboxVoiceReferencePath)
                    .textFieldStyle(.roundedBorder)
                Slider(value: $model.settings.voice.chatterboxExaggeration, in: 0.15...1.2, step: 0.05) {
                    Text("Chatterbox exaggeration")
                } minimumValueLabel: {
                    Text("0.15")
                } maximumValueLabel: {
                    Text("1.2")
                }
                Text("Chatterbox exaggeration: \(model.settings.voice.chatterboxExaggeration, specifier: "%.2f")")
                    .foregroundStyle(.secondary)
                Slider(value: $model.settings.voice.chatterboxCfgWeight, in: 0.10...1.2, step: 0.05) {
                    Text("Chatterbox CFG")
                } minimumValueLabel: {
                    Text("0.10")
                } maximumValueLabel: {
                    Text("1.2")
                }
                Text("Chatterbox CFG: \(model.settings.voice.chatterboxCfgWeight, specifier: "%.2f")")
                    .foregroundStyle(.secondary)
                TextField("Chatterbox style preset", text: $model.settings.voice.chatterboxStylePreset)
                    .textFieldStyle(.roundedBorder)
                Toggle("Use fallback voice if local TTS fails", isOn: $model.settings.voice.fallbackToAppleSpeech)
                TextField("Voice identifier", text: Binding(
                    get: { model.settings.voice.voiceIdentifier ?? "" },
                    set: { model.settings.voice.voiceIdentifier = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Stepper("Spoken summary limit: \(model.settings.voice.spokenSummaryLimit)", value: $model.settings.voice.spokenSummaryLimit, in: 60...600, step: 20)
            } label: {
                Label("Voice", systemImage: "speaker.wave.2")
            }

            GroupBox {
                Toggle("Enable follow-up context", isOn: $model.settings.session.followUpContextEnabled)
                Stepper("Idle timeout: \(model.settings.session.idleTimeoutMinutes) minutes", value: $model.settings.session.idleTimeoutMinutes, in: 5...120, step: 5)
            } label: {
                Label("Session", systemImage: "clock")
            }

            Button("Save Voice and Session Settings") { model.saveSettings() }
        }
    }

    private func addShortcut() {
        let trimmedName = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = shortcutURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), !trimmedName.isEmpty else { return }
        model.settings.shortcuts.append(ShortcutConfig(name: trimmedName, url: url))
        shortcutName = ""
        shortcutURL = ""
        model.saveSettings()
    }

    private func addContextFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path
        guard !model.settings.context.approvedFolders.contains(path) else { return }
        model.settings.context.approvedFolders.append(path)
        model.saveSettings()
    }

    private func addExclusion() {
        let pattern = exclusionPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty, !model.settings.context.exclusions.contains(pattern) else { return }
        model.settings.context.exclusions.append(pattern)
        exclusionPattern = ""
        model.saveSettings()
    }

    private func keyBinding(for provider: ProviderID) -> Binding<String> {
        switch provider {
        case .openAI:
            Binding(get: { openAIKey }, set: { openAIKey = $0 })
        case .anthropic:
            Binding(get: { anthropicKey }, set: { anthropicKey = $0 })
        case .gemini:
            Binding(get: { geminiKey }, set: { geminiKey = $0 })
        }
    }

    private func keyPlaceholder(for provider: ProviderID) -> String {
        model.providerKeyPresence[provider] == true ? "Saved key; paste a new key to replace" : "Paste key"
    }

    private func settingsProviderDisplayName(_ provider: String?) -> String {
        guard let provider else { return "None" }
        return ProviderID(rawValue: provider)?.displayName ?? provider.capitalized
    }

    private func settingsYesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private struct SettingsScrollPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
    }
}

private struct PermissionRow: View {
    let name: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.body.weight(.medium))
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}
