import AppKit
import Foundation
import JarvisCore
import JarvisDictation
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
                    Text("Mode").foregroundStyle(.secondary)
                    Text(lastMetadata.mode ?? traceText("mode"))
                }
                GridRow {
                    Text("Intent").foregroundStyle(.secondary)
                    Text(lastMetadata.intent ?? traceText("intent"))
                }
                GridRow {
                    Text("Selected capability").foregroundStyle(.secondary)
                    Text(lastMetadata.selectedCapability ?? traceText("selectedCapability"))
                }
                GridRow {
                    Text("Capabilities considered").foregroundStyle(.secondary)
                    Text(traceText("capabilitiesConsidered"))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Unavailable capabilities").foregroundStyle(.secondary)
                    Text(traceText("unavailableCapabilities"))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Selected skill").foregroundStyle(.secondary)
                    Text(lastMetadata.selectedSkill ?? traceText("selectedSkill"))
                }
                GridRow {
                    Text("Selected bundle").foregroundStyle(.secondary)
                    Text(lastMetadata.selectedBundle ?? "None")
                }
                GridRow {
                    Text("Model route").foregroundStyle(.secondary)
                    Text(lastMetadata.modelRoute ?? traceText("modelRoute"))
                }
                GridRow {
                    Text("Action risk").foregroundStyle(.secondary)
                    Text(lastMetadata.riskLevel ?? "None")
                }
                GridRow {
                    Text("Confirmation required").foregroundStyle(.secondary)
                    Text(model.session.lastStructuredResponse?.requiresConfirmation == true ? "Yes" : jsonText(lastMetadata.trace?["requiresConfirmation"]))
                }
                GridRow {
                    Text("Trace latency").foregroundStyle(.secondary)
                    Text(traceText("latencyMs") == "None" ? "None" : "\(traceText("latencyMs")) ms")
                }
                GridRow {
                    Text("Resolved target").foregroundStyle(.secondary)
                    Text(resolvedTargetText)
                        .textSelection(.enabled)
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
        let f5 = status.f5TTSImportable == true
            ? "F5-TTS ready on \(status.f5TTSDevice ?? "auto")"
            : "F5-TTS not installed"
        return "\(kokoro). \(f5)."
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

    private var resolvedTargetText: String {
        let situation = lastMetadata.situation ?? lastMetadata.trace?["situation"]?.objectValue
        let source = jsonText(situation?["targetSource"])
        let confidence = jsonText(situation?["confidence"])
        if source == "None" {
            return "None"
        }
        return "\(source), confidence \(confidence)"
    }

    private func traceText(_ key: String) -> String {
        jsonText(lastMetadata.trace?[key])
    }

    private func jsonText(_ value: JSONValue?) -> String {
        guard let value else { return "None" }
        switch value {
        case .string(let string):
            return string.isEmpty ? "None" : string
        case .number(let number):
            return String(format: number.rounded() == number ? "%.0f" : "%.2f", number)
        case .bool(let bool):
            return yesNo(bool)
        case .array(let array):
            guard !array.isEmpty else { return "None" }
            return array.map { jsonText($0) }.joined(separator: ", ")
        case .object(let object):
            guard !object.isEmpty else { return "None" }
            return object.keys.sorted().joined(separator: ", ")
        case .null:
            return "None"
        }
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
    @State private var skillSearchQuery = ""
    @State private var skillLearnName = ""
    @State private var skillLearnSource = ""

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
            assistantModes
                .tabItem { Label("Modes", systemImage: "slider.horizontal.3") }
            capabilities
                .tabItem { Label("Capabilities", systemImage: "checklist") }
            contextSettings
                .tabItem { Label("Context", systemImage: "scope") }
            privacy
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            skills
                .tabItem { Label("Skills", systemImage: "wand.and.stars") }
            dictation
                .tabItem { Label("Dictation", systemImage: "mic") }
            prompts
                .tabItem { Label("Prompts", systemImage: "text.quote") }
            voiceSession
                .tabItem { Label("Voice", systemImage: "speaker.wave.2") }
            performance
                .tabItem { Label("Performance", systemImage: "bolt") }
            scheduled
                .tabItem { Label("Scheduled", systemImage: "calendar.badge.clock") }
            dashboard
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") }
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

    private var assistantModes: some View {
        SettingsScrollPage {
            GroupBox {
                statusRow("Default", model.defaultAssistantMode)
                statusRow("Available", "\(model.assistantModes.count)")
            } label: {
                Label("Assistant Modes", systemImage: "slider.horizontal.3")
            }

            ForEach(model.assistantModes) { mode in
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Trigger")
                                Text(mode.trigger).foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Execution")
                                Text(mode.executionType).foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Model route")
                                Text(mode.defaultModelRoute).foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Response")
                                Text("\(mode.responseStyle), \(mode.maxResponseLength)").foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Skills")
                                Text(joinedOrDash(mode.allowedSkills)).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        statusRow("Context", policySummary(mode.contextPolicy))
                        statusRow("Risk", policySummary(mode.riskPolicy))
                        statusRow("Speech", policySummary(mode.speechPolicy))
                    }
                } label: {
                    Label(mode.name, systemImage: modeIcon(mode.executionType))
                }
            }

            HStack {
                Button("Refresh") { model.refreshAssistantModes() }
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshAssistantModes() }
    }

    private var capabilities: some View {
        SettingsScrollPage {
            HStack(alignment: .firstTextBaseline) {
                if let report = model.capabilityReport {
                    Text("\(report.available.count) available, \(report.unavailable.count) unavailable")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No capability data loaded.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { model.refreshCapabilities() }
            }

            if let report = model.capabilityReport {
                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("Identity")
                            Text("\(report.identity.name), \(report.identity.product)")
                                .foregroundStyle(.secondary)
                        }
                        GridRow {
                            Text("Mode")
                            Text(report.mode)
                                .foregroundStyle(.secondary)
                        }
                        GridRow {
                            Text("Skills")
                            Text("\(report.installedSkills.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Label("Self Model", systemImage: "person.crop.circle.badge.checkmark")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.available) { capability in
                            capabilityRow(capability)
                            Divider()
                        }
                    }
                } label: {
                    Label("Available Now", systemImage: "checkmark.circle")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.unavailable) { capability in
                            capabilityRow(capability)
                            Divider()
                        }
                    }
                } label: {
                    Label("Unavailable Now", systemImage: "minus.circle")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.actionRules, id: \.self) { rule in
                            Text(rule)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } label: {
                    Label("Action Rules", systemImage: "exclamationmark.shield")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("Skill write approval", jsonText(model.skillsConfig?["skills"]?.objectValue?["writeApproval"]))
                        statusRow("Pending changes", "\(model.pendingSkillChanges.count)")
                        statusRow("Shell actions", model.capabilityReport?.unavailable.contains(where: { $0.id == "developer.run_confirmed_shell_command" }) == true ? "disabled" : "available with confirmation")
                    }
                } label: {
                    Label("Automation Safety", systemImage: "lock.shield")
                }
            }
        }
        .onAppear {
            model.refreshCapabilities()
            model.refreshSkills()
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

    private var skills: some View {
        SettingsScrollPage {
            HStack(alignment: .firstTextBaseline) {
                TextField("Search skills", text: $skillSearchQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Refresh") { model.refreshSkills() }
            }

            GroupBox {
                if filteredSkills.isEmpty {
                    Text("No installed skills found.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(filteredSkills) { skill in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(skill.name)
                                    .font(.body.weight(.medium))
                                Text(skill.riskLevel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(skillRiskColor(skill.riskLevel))
                            }
                            Text(skill.description)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text("\(skill.category) · \(skill.allowedModes.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            model.inspectSkill(skill)
                        } label: {
                            Label("View", systemImage: "doc.text.magnifyingglass")
                        }
                        .labelStyle(.iconOnly)
                        .help("View skill")
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            } label: {
                Label("Installed Skills", systemImage: "books.vertical")
            }

            if let detail = model.selectedSkillDetail {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        statusRow("Name", detail.name)
                        statusRow("Version", detail.version ?? "—")
                        statusRow("Category", detail.category ?? "—")
                        statusRow("Risk", detail.riskLevel ?? "—")
                        if let warnings = detail.warnings, !warnings.isEmpty {
                            Text(warnings.joined(separator: "\n"))
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                        }
                        Text(String((detail.body ?? detail.raw ?? "").prefix(2400)))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } label: {
                    Label("Skill Detail", systemImage: "doc.text")
                }
            }

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Name")
                        TextField("dealer-outreach-message", text: $skillLearnName)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Workflow")
                        TextEditor(text: $skillLearnSource)
                            .font(.body)
                            .frame(minHeight: 90)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                }
                HStack {
                    Button("Stage Skill") {
                        model.learnSkill(source: skillLearnSource, name: skillLearnName)
                    }
                    .disabled(skillLearnSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Clear") {
                        skillLearnName = ""
                        skillLearnSource = ""
                    }
                    Text(model.statusLine)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } label: {
                Label("Learn New Skill", systemImage: "plus.square.on.square")
            }

            GroupBox {
                if model.pendingSkillChanges.isEmpty {
                    Text("No pending skill changes.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(model.pendingSkillChanges) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(change.skillName)
                                    .font(.body.weight(.medium))
                                Text(change.summary)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if !change.warnings.isEmpty {
                                    Text(change.warnings.joined(separator: "\n"))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .textSelection(.enabled)
                                }
                            }
                            Spacer()
                            Button("Diff") { model.showSkillDiff(change) }
                            Button("Approve") { model.approveSkillChange(change) }
                            Button("Reject") { model.rejectSkillChange(change) }
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
                if let diff = model.selectedSkillDiff {
                    Divider()
                    Text("Diff: \(diff.skillName)")
                        .font(.headline)
                    ScrollView(.horizontal) {
                        Text(diff.diff.isEmpty ? "No diff available." : diff.diff)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
            } label: {
                Label("Pending Skill Changes", systemImage: "checklist.checked")
            }

            GroupBox {
                if model.skillBundles.isEmpty {
                    Text("No skill bundles found.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(model.skillBundles) { bundle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bundle.name)
                            .font(.body.weight(.medium))
                        if let description = bundle.description, !description.isEmpty {
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                        Text(bundle.skills.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let instruction = bundle.instruction, !instruction.isEmpty {
                            Text(instruction)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            } label: {
                Label("Skill Bundles", systemImage: "square.stack.3d.up")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if let config = model.skillsConfig?["skills"]?.objectValue {
                        statusRow("Enabled", jsonText(config["enabled"]))
                        statusRow("Write approval", jsonText(config["writeApproval"]))
                        statusRow("External directories", jsonText(config["externalDirs"]))
                        statusRow("GitHub install", jsonText(config["allowGitHubSkillInstall"]))
                        statusRow("Remote install", jsonText(config["allowRemoteSkillInstall"]))
                        statusRow("Root", jsonText(config["root"]))
                    } else {
                        Text("Skill config has not loaded yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Skill Permissions", systemImage: "lock.shield")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if model.skillRunHistory.isEmpty {
                        Text("No skill runs recorded yet.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(model.skillRunHistory.prefix(8))) { run in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(run.name)
                                    .font(.body.weight(.medium))
                                Text(run.kind)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(skillRunTime(run.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(skillRunSummary(run))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            if !run.loadedSkills.isEmpty {
                                Text("Loaded: \(joinedOrDash(run.loadedSkills))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            if !run.warnings.isEmpty {
                                Text(run.warnings.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .textSelection(.enabled)
                            }
                        }
                        Divider()
                    }
                }
            } label: {
                Label("Skill Run History", systemImage: "clock.arrow.circlepath")
            }
        }
        .onAppear { model.refreshSkills() }
    }

    private var dictation: some View {
        SettingsScrollPage {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Assistant hotkey")
                        Text(model.settings.dictation.assistantHotkey)
                            .foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text("Dictation hotkey")
                        Picker("Dictation hotkey", selection: $model.settings.dictation.dictationHotkey) {
                            ForEach(DictationHotkey.allCases) { hotkey in
                                Text(hotkey.displayName).tag(hotkey)
                            }
                        }
                    }
                    GridRow {
                        Text("Hands-free")
                        Toggle("Double-tap hotkey", isOn: $model.settings.dictation.handsFreeDictation)
                    }
                    GridRow {
                        Text("Insert")
                        Toggle("Automatically insert at cursor", isOn: $model.settings.dictation.insertAutomatically)
                    }
                    GridRow {
                        Text("Sound")
                        Toggle("Play sound feedback", isOn: $model.settings.dictation.playSoundFeedback)
                    }
                }
            } label: {
                Label("Hotkeys and Insertion", systemImage: "keyboard")
            }

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("STT engine")
                        Picker("STT engine", selection: $model.settings.dictation.sttEngine) {
                            ForEach(STTEngine.allCases) { engine in
                                Text(engine.displayName).tag(engine)
                            }
                        }
                    }
                    GridRow {
                        Text("Post-processing")
                        Picker("Post-processing", selection: $model.settings.dictation.postProcessing) {
                            ForEach(DictationPostProcessing.allCases) { processing in
                                Text(processing.displayName).tag(processing)
                            }
                        }
                    }
                }
                if let backend = model.dictationBackendStatus {
                    Divider()
                    statusRow("Brain dictation", backend.available ? "Available" : "Unavailable")
                    statusRow("STT engines", backend.sttEngines.joined(separator: ", "))
                    statusRow("Post-processing", backend.postProcessing.joined(separator: ", "))
                }
            } label: {
                Label("Transcription Pipeline", systemImage: "waveform")
            }

            GroupBox {
                DictationStatusView(status: model.dictationStatus)
                    .frame(maxWidth: .infinity, alignment: .leading)
                statusRow("Phase", model.dictationStatus.phase.rawValue)
                statusRow("Active app", model.dictationStatus.activeAppName ?? "—")
                statusRow("Last inserted", model.dictationStatus.insertedText.isEmpty ? "—" : model.dictationStatus.insertedText)
            } label: {
                Label("Current Dictation", systemImage: "mic.badge.plus")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dictation cleanup prompt")
                        .font(.body.weight(.medium))
                    TextEditor(text: $model.settings.dictation.dictationPrompt)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                    Text("Email formatting prompt")
                        .font(.body.weight(.medium))
                    TextEditor(text: $model.settings.dictation.emailPrompt)
                        .frame(minHeight: 70)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                    Text("Writing style prompt")
                        .font(.body.weight(.medium))
                    TextEditor(text: $model.settings.dictation.writingStylePrompt)
                        .frame(minHeight: 70)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
            } label: {
                Label("Prompts", systemImage: "text.quote")
            }

            HStack {
                Button("Save Dictation Settings") { model.saveSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Refresh") { model.refreshDashboard() }
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshDashboard() }
    }

    private var prompts: some View {
        SettingsScrollPage {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    promptEditor("Assistant Prompt", text: $model.settings.prompts.assistantPrompt, minHeight: 120)
                    promptEditor("Command Interpretation Prompt", text: $model.settings.prompts.commandInterpretationPrompt, minHeight: 90)
                    promptEditor("Skill Learning Prompt", text: $model.settings.prompts.skillLearningPrompt, minHeight: 90)
                }
            } label: {
                Label("Assistant", systemImage: "sparkles")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    promptEditor("Dictation Cleanup Prompt", text: $model.settings.dictation.dictationPrompt, minHeight: 90)
                    promptEditor("Email Formatting Prompt", text: $model.settings.dictation.emailPrompt, minHeight: 80)
                    promptEditor("Writing Style Prompt", text: $model.settings.dictation.writingStylePrompt, minHeight: 80)
                }
            } label: {
                Label("Writing and Dictation", systemImage: "text.cursor")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow("Assistant", promptSource("assistant"))
                    statusRow("Dictation", promptSource("dictation"))
                    statusRow("Email", promptSource("email"))
                    statusRow("Writing style", promptSource("writing_style"))
                    statusRow("Skill learning", promptSource("skill_learning"))
                    statusRow("Command interpretation", promptSource("command_interpretation"))
                }
            } label: {
                Label("Prompt Sources", systemImage: "externaldrive")
            }

            HStack {
                Button("Save Prompts") { model.saveSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Refresh") { model.refreshDashboard() }
                Button("Reset Drafts") { model.resetLocalPromptsToDefaults() }
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshDashboard() }
    }

    private var scheduled: some View {
        SettingsScrollPage {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    statusRow("Runner", model.scheduledAgentStatus)
                    statusRow("Active agents", "\(model.scheduledAgents.filter { $0.enabled && $0.type == "scheduled" }.count)")
                    if let lastRun = model.lastScheduledAgentRun {
                        statusRow("Last automatic run", lastRun.agent.name)
                    }
                    if let lastRunAt = model.lastScheduledAgentRunAt {
                        statusRow("Last run time", lastRunAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            } label: {
                Label("Runner", systemImage: "clock.badge.checkmark")
            }

            ForEach(model.scheduledAgents) { agent in
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Text("Enabled")
                                Toggle("", isOn: Binding(
                                    get: { agent.enabled },
                                    set: { model.setScheduledAgentEnabled(agent, enabled: $0) }
                                ))
                                .labelsHidden()
                            }
                            GridRow {
                                Text("Type")
                                Text(agent.type)
                                    .foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Time")
                                Text("\(agent.time) \(agent.timezone)")
                                    .foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("Next run")
                                Text(agent.nextRunAt ?? "—")
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sources")
                                .font(.body.weight(.medium))
                            ForEach(scheduledSourceKeys, id: \.self) { source in
                                Toggle(scheduledSourceTitle(source), isOn: Binding(
                                    get: { agent.sources[source] == true },
                                    set: { model.setScheduledAgentSource(agent, source: source, enabled: $0) }
                                ))
                                .disabled(sourceIsFutureOnly(source))
                            }
                        }

                        HStack {
                            Button("Preview") { model.previewScheduledAgent(agent) }
                            Text(agent.requiresOptIn ? "Opt-in only" : "Available")
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Label(agent.name, systemImage: agent.enabled ? "calendar.badge.checkmark" : "calendar")
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    if let schedule = visibleScheduleContext {
                        statusRow("Calendars", schedule.calendarAuthorization)
                        statusRow("Reminders", schedule.reminderAuthorization)
                        statusRow("Events", "\(schedule.events.count)")
                        statusRow("Reminder items", "\(schedule.reminders.count)")
                        statusRow("Generated", schedule.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("No local schedule snapshot is available.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Refresh Schedule Snapshot") { model.refreshScheduleContext() }
                }
            } label: {
                Label("Local Schedule Snapshot", systemImage: "calendar")
            }

            if let preview = model.scheduledAgentPreview {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preview.answer)
                            .textSelection(.enabled)
                        statusRow("Sources used", joinedOrDash(preview.sourcesUsed))
                        statusRow("Speak", preview.speak.isEmpty ? "—" : preview.speak)
                    }
                } label: {
                    Label("Last Preview", systemImage: "doc.text.magnifyingglass")
                }
            }

            HStack {
                Button("Refresh") { model.refreshScheduledAgents() }
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshScheduledAgents() }
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
                TextField("F5-TTS reference audio path", text: $model.settings.voice.f5VoiceReferencePath)
                    .textFieldStyle(.roundedBorder)
                TextField("F5-TTS reference transcript", text: $model.settings.voice.f5ReferenceText)
                    .textFieldStyle(.roundedBorder)
                Slider(value: $model.settings.voice.f5CfgStrength, in: 0.5...5.0, step: 0.1) {
                    Text("F5-TTS CFG strength")
                } minimumValueLabel: {
                    Text("0.5")
                } maximumValueLabel: {
                    Text("5.0")
                }
                Text("F5-TTS CFG strength: \(model.settings.voice.f5CfgStrength, specifier: "%.1f")")
                    .foregroundStyle(.secondary)
                Stepper("F5-TTS inference steps: \(model.settings.voice.f5NfeStep)", value: $model.settings.voice.f5NfeStep, in: 8...64, step: 4)
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

    private var filteredSkills: [SkillSummary] {
        let query = skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return model.installedSkills }
        return model.installedSkills.filter { skill in
            "\(skill.name) \(skill.description) \(skill.category) \(skill.allowedModes.joined(separator: " "))"
                .lowercased()
                .contains(query)
        }
    }

    private func skillRiskColor(_ risk: String) -> Color {
        switch risk.lowercased() {
        case "green":
            return .green
        case "yellow":
            return .orange
        case "red":
            return .red
        default:
            return .secondary
        }
    }

    private func capabilityRow(_ capability: CapabilitySummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: capability.available ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(capability.available ? .green : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(capability.name)
                        .font(.body.weight(.medium))
                    Text(capability.riskLevel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(skillRiskColor(capability.riskLevel))
                    if capability.requiresConfirmation {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                            .help("Requires confirmation")
                    }
                }
                Text(capability.description)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(capabilityMeta(capability))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if !capability.statusReason.isEmpty {
                    Text(capability.statusReason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func capabilityMeta(_ capability: CapabilitySummary) -> String {
        var pieces = [capability.id, capability.category, capability.source]
        if !capability.requiredConnectors.isEmpty {
            pieces.append("connectors: \(capability.requiredConnectors.joined(separator: ", "))")
        }
        if !capability.requiredPermissions.isEmpty {
            pieces.append("permissions: \(capability.requiredPermissions.joined(separator: ", "))")
        }
        return pieces.joined(separator: " · ")
    }

    private func skillRunTime(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
        }
        return value
    }

    private func skillRunSummary(_ run: SkillRunRecord) -> String {
        var parts = [run.status, run.route]
        if let mode = run.mode, !mode.isEmpty {
            parts.append(mode)
        }
        if run.requiresConfirmation {
            parts.append("needs confirmation")
        }
        if !run.missingSkills.isEmpty {
            parts.append("missing: \(joinedOrDash(run.missingSkills))")
        }
        return parts.joined(separator: " · ")
    }

    private func jsonText(_ value: JSONValue?) -> String {
        guard let value else { return "—" }
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            return String(format: "%.0f", number)
        case .bool(let bool):
            return settingsYesNo(bool)
        case .array(let array):
            guard !array.isEmpty else { return "None" }
            return array.map { jsonText($0) }.joined(separator: ", ")
        case .object(let object):
            guard !object.isEmpty else { return "None" }
            return object.keys.sorted().joined(separator: ", ")
        case .null:
            return "None"
        }
    }

    private func traceSummary(_ trace: [String: JSONValue]?) -> String {
        guard let trace, !trace.isEmpty else { return "—" }
        let mode = jsonText(trace["mode"])
        let intent = jsonText(trace["intent"])
        let route = jsonText(trace["modelRoute"])
        let latency = jsonText(trace["latencyMs"])
        return "mode \(mode), intent \(intent), route \(route), \(latency) ms"
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

    private var performance: some View {
        SettingsScrollPage {
            GroupBox {
                Picker("Mode", selection: Binding(
                    get: { model.settings.performance.mode },
                    set: { model.setPerformanceMode($0) }
                )) {
                    ForEach(PerformanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.settings.performance.mode.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Performance Mode", systemImage: "bolt")
            }

            if let report = model.performanceReport {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("Active mode", report.mode.capitalized)
                        statusRow("File index default", report.toggles.fileIndexDefaultMode)
                        statusRow("Background full indexing", settingsYesNo(report.toggles.backgroundFullIndexing))
                        statusRow("F5-TTS preload", settingsYesNo(report.toggles.f5TTSPreload))
                        statusRow("Memory suggestions", settingsYesNo(report.toggles.memorySuggestions))
                        statusRow("Screenshot fallback", settingsYesNo(report.toggles.screenshotFallback))
                        statusRow("Shortest spoken replies", settingsYesNo(report.toggles.shortestSpokenResponses))
                        statusRow("Richer context packs", settingsYesNo(report.toggles.richerContextPacks))
                    }
                } label: {
                    Label("Active Policy (from brain)", systemImage: "checklist")
                }
            }

            Button("Refresh") { model.refreshDashboard() }
        }
        .onAppear { model.refreshDashboard() }
    }

    private var dashboard: some View {
        SettingsScrollPage {
            HStack(alignment: .firstTextBaseline) {
                Text("Live status of what Jarvis is currently running.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { model.refreshDashboard() }
            }

            if let report = model.performanceDashboard {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("Brain running", settingsYesNo(report.brainRunning ?? false))
                        statusRow("Performance mode", (report.performanceMode ?? "—").capitalized)
                    }
                } label: {
                    Label("Overview", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

                if let fileIndex = report.fileIndex {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            statusRow("Mode", fileIndex.mode ?? "—")
                            statusRow("Indexing now", settingsYesNo(fileIndex.currentlyIndexing ?? false))
                            statusRow("Watching", settingsYesNo(fileIndex.watching ?? false))
                            statusRow("File count", "\(fileIndex.fileCount ?? 0)")
                            statusRow("Scanned this run", "\(fileIndex.filesScannedThisRun ?? 0)")
                            statusRow("Skipped this run", "\(fileIndex.filesSkippedThisRun ?? 0)")
                            if let current = fileIndex.currentFile, !current.isEmpty {
                                statusRow("Current file", current)
                            }
                        }
                    } label: {
                        Label("File Index", systemImage: "folder")
                    }
                }

                if let tts = report.tts {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            statusRow("Engine loaded", tts.engineLoaded ?? "none")
                            statusRow("F5-TTS worker", settingsYesNo(tts.f5TTSWorkerRunning ?? false))
                            statusRow("Last engine used", tts.lastEngineUsed ?? "—")
                            statusRow("Last TTS latency", latencyText(tts.lastLatencyMs))
                        }
                    } label: {
                        Label("Text-to-Speech", systemImage: "speaker.wave.2")
                    }
                }

                if let providers = report.providers {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            statusRow("Last model", providers.lastModelUsed ?? "—")
                            statusRow("Last latency", latencyText(providers.lastLatencyMs))
                            statusRow("Last Gemini latency", latencyText(providers.lastGeminiLatencyMs))
                        }
                    } label: {
                        Label("Providers", systemImage: "cpu")
                    }
                }

                if let chat = report.chat {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            statusRow("Last route", chat.lastRoute ?? "—")
                            statusRow("Last context pack size", "\(chat.lastContextPackSize ?? 0)")
                        }
                    } label: {
                        Label("Last Turn", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }

                if let services = report.backgroundServices, !services.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(services) { service in
                                statusRow(service.name, settingsYesNo(service.running))
                            }
                        }
                    } label: {
                        Label("Active Background Services", systemImage: "list.bullet")
                    }
                }
            } else {
                Text("No dashboard data yet. Press Refresh.")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refreshDashboard() }
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func latencyText(_ milliseconds: Double?) -> String {
        guard let milliseconds else { return "—" }
        return String(format: "%.0f ms", milliseconds)
    }

    private func joinedOrDash(_ values: [String]) -> String {
        values.isEmpty ? "—" : values.joined(separator: ", ")
    }

    private func promptEditor(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.medium))
            TextEditor(text: text)
                .font(.body.monospaced())
                .frame(minHeight: minHeight)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
        }
    }

    private func promptSource(_ id: String) -> String {
        guard let prompt = model.editablePrompts.first(where: { $0.id == id }) else {
            return "Local draft"
        }
        return prompt.source == "user" ? "Saved override" : "Default"
    }

    private var scheduledSourceKeys: [String] {
        ["calendar", "reminders", "email", "weather", "news", "tasks"]
    }

    private var visibleScheduleContext: ScheduleContext? {
        model.latestScheduleContext ?? model.session.lastScreenContext?.schedule
    }

    private func scheduledSourceTitle(_ source: String) -> String {
        switch source {
        case "calendar":
            "Calendar"
        case "reminders":
            "Reminders"
        case "email":
            "Email summary"
        case "weather":
            "Weather"
        case "news":
            "News"
        case "tasks":
            "Tasks"
        default:
            source.capitalized
        }
    }

    private func sourceIsFutureOnly(_ source: String) -> Bool {
        !["calendar", "reminders"].contains(source)
    }

    private func modeIcon(_ executionType: String) -> String {
        switch executionType {
        case "scheduled":
            "calendar.badge.clock"
        case "continuous":
            "eye"
        default:
            "command"
        }
    }

    private func policySummary(_ policy: [String: JSONValue]) -> String {
        guard !policy.isEmpty else { return "—" }
        return policy.keys.sorted().map { key in
            "\(key): \(jsonText(policy[key]))"
        }
        .joined(separator: ", ")
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
