import Combine
import Foundation
import JarvisContext
import JarvisCore
import JarvisDictation
import JarvisMac
import SwiftUI

private struct FollowUpPromptPlan {
    var spokenPrompt: String?
    var listeningPrompt: String?
}

@MainActor
public final class JarvisAppModel: ObservableObject {
    public static let shared = JarvisAppModel()

    @Published public var phase: AssistantPhase = .idle
    @Published public var settings: AppSettings
    @Published public var session: SessionStore
    @Published public var brainReady = false
    @Published public var lastTranscript = ""
    @Published public var statusLine = "Option-Space to talk"
    @Published public var providerKeyPresence: [ProviderID: Bool] = [:]
    @Published public var providerDiagnostics: ProviderDiagnosticsReport?
    @Published public var memoryStatus: MemoryStatusReport?
    @Published public var ttsStatus: TTSStatusReport?
    @Published public var fileIndexStatus: FileIndexStatusReport?
    @Published public var performanceReport: PerformanceModeReport?
    @Published public var performanceDashboard: DashboardReport?
    @Published public var assistantModes: [AssistantModeReport] = []
    @Published public var defaultAssistantMode = "quick_assistant"
    @Published public var capabilityReport: CapabilityReport?
    @Published public var installedSkills: [SkillSummary] = []
    @Published public var pendingSkillChanges: [PendingSkillChange] = []
    @Published public var selectedSkillDiff: PendingSkillDiff?
    @Published public var selectedSkillDetail: SkillDetail?
    @Published public var skillBundles: [SkillBundle] = []
    @Published public var skillRunHistory: [SkillRunRecord] = []
    @Published public var skillsConfig: [String: JSONValue]?
    @Published public var editablePrompts: [JarvisPrompt] = []
    @Published public var scheduledAgents: [ScheduledAgent] = []
    @Published public var scheduledAgentPreview: ScheduledAgentPreviewReport?
    @Published public var lastScheduledAgentRun: ScheduledAgentPreviewReport?
    @Published public var lastScheduledAgentRunAt: Date?
    @Published public var scheduledAgentStatus = "No active scheduled agents"
    @Published public var latestScheduleContext: ScheduleContext?
    @Published public var dictationStatus: DictationStatus = .idle
    @Published public var dictationBackendStatus: DictationStatusReport?
    @Published public var modelBadgeText = "Local"
    @Published public var activeTurn: AssistantTurn?
    @Published public var turnWarnings: [String] = []
    @Published public var ttsDebugLog: [String] = []
    public var scheduleContextProvider: (@MainActor () async -> ScheduleContext?)?
    public var onLocalActionWillExecute: (@MainActor (AssistantAction) -> Void)?

    private let settingsStore = SettingsStore()
    private let keychain = KeychainManager()
    private let commandMatcher = CommandMatcher()
    private let localAnswerRouter = LocalAnswerRouter()
    private let intentRouter = IntentRouter()
    private let intentClassifier: IntentClassifying = IntentRouter()
    private let localModel = LocalModelClient()
    private let responseComposer = ResponseComposer()
    private let followUpResolver = FollowUpResolver()
    private let actionRegistry = ActionRegistry()
    private let actionExecutor = ActionExecutor()
    private let contextBuilder = ContextBuilder()
    private let targetCapture = TargetAppCapture()
    private let dictation = DictationController()
    private let speech = SpeechTranscriberManager()
    private let tts = TTSManager()
    private let hotkey = GlobalHotkeyManager()
    private let flow = ConversationFlowController()
    private let brainProcess: BrainProcessManager
    private let brainClient: BrainClient
    private var panelController: NotchPanelController?
    private var started = false
    private var responseBeingSpoken: StructuredResponse?
    private var pendingFollowUpPrompt: String?
    private var lastFollowUpPrompt = ""
    private var endConversationAfterSpeech = false
    private var scheduledAgentTask: Task<Void, Never>?
    private var scheduledAgentRunInProgress = false

    private static let scheduledAgentPollIntervalNanoseconds: UInt64 = 60 * 1_000_000_000

    private init() {
        let loadedSettings = settingsStore.load()
        settings = loadedSettings
        session = SessionStore(expiresAt: Date().addingTimeInterval(TimeInterval(loadedSettings.session.idleTimeoutMinutes * 60)))
        let process = BrainProcessManager(keychain: keychain, settings: loadedSettings)
        brainProcess = process
        brainClient = BrainClient(baseURL: URL(string: "http://127.0.0.1:\(process.port)")!, token: process.token)
    }

    public func start() {
        start(embeddedInHostShell: false)
    }

    public func startEmbedded() {
        start(embeddedInHostShell: true)
    }

    private func start(embeddedInHostShell: Bool) {
        guard !started else { return }
        started = true
        if !embeddedInHostShell {
            panelController = NotchPanelController(model: self)
        }
        configureSpeech()
        configureDictation()
        configureTTSCallbacks()
        configureFlow()
        refreshKeyPresence()
        tts.configure(settings: settings.voice, brainClient: brainClient)
        if !embeddedInHostShell {
            hotkey.registerOptionSpace { [weak self] in
                self?.toggleFromHotkey()
            }
        }
        brainProcess.startIfNeeded(settings: settings)
        Task {
            brainReady = await waitForBrainReady()
            if !brainReady {
                brainProcess.restart(settings: settings)
                brainReady = await waitForBrainReady()
            }
            statusLine = brainReady ? "Ready when you are" : "Local commands are ready"
            await refreshRuntimeStatus()
            restartScheduledAgentLoop()
        }
    }

    public func shutdown() {
        scheduledAgentTask?.cancel()
        scheduledAgentTask = nil
        flow.cancelTimers()
        dictation.unregister()
        hotkey.unregister()
        brainProcess.stop()
    }

    public func toggleFromHotkey() {
        switch phase {
        case .idle, .error, .results:
            flow.cancelTimers()
            Task { await startListening() }
        case .listening, .transcribing:
            submitCurrentSpeechTranscript()
        case .speaking:
            pendingFollowUpPrompt = nil
            tts.stop()
            Task { await startListening() }
        case .thinking, .acting:
            flow.cancelTimers()
            flow.clearAwaitingFollowUp()
            cancelActiveTurn()
            phase = .idle
            panelController?.hide()
        case .confirming:
            break
        }
    }

    public func saveSettings() {
        do {
            try settingsStore.save(settings)
            tts.configure(settings: settings.voice, brainClient: brainClient)
            configureDictation()
            applyPromptSettingsToLocalReports()
            statusLine = "Settings saved"
            refreshBrainAfterSettingsChange(message: "Settings saved")
        } catch {
            statusLine = "Could not save settings: \(error.localizedDescription)"
        }
    }

    public func saveAPIKey(_ key: String, for provider: ProviderID) {
        do {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                statusLine = "Paste a key to replace it, or use Remove key."
                refreshKeyPresence()
                return
            }
            try keychain.setAPIKey(trimmed, for: provider)
            enableProviderForSavedKey(provider)
            try settingsStore.save(settings)
            refreshKeyPresence()
            statusLine = "\(provider.displayName) key saved. Reconnecting..."
            refreshBrainAfterSettingsChange(message: "\(provider.displayName) key saved", testProvider: provider)
        } catch {
            statusLine = "Could not save key: \(error.localizedDescription)"
        }
    }

    public func removeAPIKey(for provider: ProviderID) {
        do {
            try keychain.deleteAPIKey(for: provider)
            refreshKeyPresence()
            statusLine = "\(provider.displayName) key removed. Reconnecting..."
            refreshBrainAfterSettingsChange(message: "\(provider.displayName) key removed")
        } catch {
            statusLine = "Could not remove key: \(error.localizedDescription)"
        }
    }

    public func testProviders() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let report = try await brainClient.testProviders()
                statusLine = providerStatusLine(from: report, preferredProvider: nil)
                await refreshRuntimeStatus()
            } catch {
                statusLine = "Provider test failed: \(error.localizedDescription)"
            }
        }
    }

    public func refreshFileIndexStatus() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                fileIndexStatus = try await fileIndexClient().status()
                statusLine = "File index status refreshed"
            } catch {
                statusLine = "File index status failed: \(error.localizedDescription)"
            }
        }
    }

    public func startFileIndex() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                fileIndexStatus = try await fileIndexClient().start()
                statusLine = "File index is watching approved folders"
            } catch {
                statusLine = "File index start failed: \(error.localizedDescription)"
            }
        }
    }

    public func stopFileIndex() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                fileIndexStatus = try await fileIndexClient().stop()
                statusLine = "File index stopped"
            } catch {
                statusLine = "File index stop failed: \(error.localizedDescription)"
            }
        }
    }

    public func reindexFileIndex() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                fileIndexStatus = try await fileIndexClient().reindex()
                statusLine = "File index refreshed"
            } catch {
                statusLine = "File reindex failed: \(error.localizedDescription)"
            }
        }
    }

    public func setPerformanceMode(_ mode: PerformanceMode) {
        settings.performance.mode = mode
        saveSettings()
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                performanceReport = try await brainClient.setPerformanceMode(mode.rawValue)
                statusLine = "Performance mode: \(mode.displayName)"
                await refreshDashboardAsync()
            } catch {
                statusLine = "Performance mode update failed: \(error.localizedDescription)"
            }
        }
    }

    public func refreshDashboard() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            await refreshDashboardAsync()
            statusLine = "Dashboard refreshed"
        }
    }

    public func resetLocalPromptsToDefaults() {
        settings.prompts = PromptSettings()
        settings.dictation.dictationPrompt = DictationSettings.defaultDictationPrompt
        settings.dictation.emailPrompt = DictationSettings.defaultEmailPrompt
        settings.dictation.writingStylePrompt = ""
        applyPromptSettingsToLocalReports()
        statusLine = "Prompt drafts reset. Save settings to apply."
    }

    public func refreshSkills() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            await refreshSkillsAsync()
            statusLine = "Skills refreshed"
        }
    }

    public func refreshScheduledAgents() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            _ = await captureScheduleContext()
            await refreshScheduledAgentsAsync()
            restartScheduledAgentLoop()
            statusLine = "Scheduled agents refreshed"
        }
    }

    public func refreshScheduleContext() {
        Task {
            if await captureScheduleContext() != nil {
                statusLine = "Schedule context refreshed"
            } else {
                statusLine = "No schedule connector is attached."
            }
        }
    }

    public func refreshAssistantModes() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            await refreshAssistantModesAsync()
            statusLine = "Assistant modes refreshed"
        }
    }

    public func refreshCapabilities() {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                capabilityReport = try await brainClient.capabilities()
                statusLine = "Capabilities refreshed"
            } catch {
                statusLine = "Capabilities refresh failed: \(error.localizedDescription)"
            }
        }
    }

    public func setScheduledAgentEnabled(_ agent: ScheduledAgent, enabled: Bool) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let updated = try await brainClient.updateScheduledAgent(id: agent.id, enabled: enabled)
                replaceScheduledAgent(updated)
                restartScheduledAgentLoop()
                statusLine = "\(updated.name) \(updated.enabled ? "enabled" : "disabled")"
            } catch {
                statusLine = "Scheduled agent update failed: \(error.localizedDescription)"
            }
        }
    }

    public func setScheduledAgentSource(_ agent: ScheduledAgent, source: String, enabled: Bool) {
        var sources = agent.sources
        sources[source] = enabled
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let updated = try await brainClient.updateScheduledAgent(id: agent.id, sources: sources)
                replaceScheduledAgent(updated)
                restartScheduledAgentLoop()
                statusLine = "\(updated.name) sources updated"
            } catch {
                statusLine = "Scheduled agent source update failed: \(error.localizedDescription)"
            }
        }
    }

    public func previewScheduledAgent(_ agent: ScheduledAgent) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let schedule = await captureScheduleContext()
                scheduledAgentPreview = try await brainClient.previewScheduledAgent(
                    id: agent.id,
                    schedule: schedule
                )
                statusLine = "Previewed \(agent.name)"
            } catch {
                statusLine = "Scheduled agent preview failed: \(error.localizedDescription)"
            }
        }
    }

    public func inspectSkill(_ skill: SkillSummary) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                selectedSkillDetail = try await brainClient.skill(name: skill.name)
                statusLine = "Loaded \(skill.name)"
            } catch {
                statusLine = "Skill load failed: \(error.localizedDescription)"
            }
        }
    }

    public func showSkillDiff(_ change: PendingSkillChange) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                selectedSkillDiff = try await brainClient.pendingSkillDiff(id: change.id)
                statusLine = "Loaded diff for \(change.skillName)"
            } catch {
                statusLine = "Skill diff failed: \(error.localizedDescription)"
            }
        }
    }

    public func approveSkillChange(_ change: PendingSkillChange) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let approved = try await brainClient.approveSkillChange(id: change.id)
                selectedSkillDiff = nil
                await refreshSkillsAsync()
                statusLine = "Approved \(approved.skillName)"
            } catch {
                statusLine = "Skill approval failed: \(error.localizedDescription)"
            }
        }
    }

    public func rejectSkillChange(_ change: PendingSkillChange) {
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let rejected = try await brainClient.rejectSkillChange(id: change.id)
                selectedSkillDiff = nil
                await refreshSkillsAsync()
                statusLine = "Rejected \(rejected.skillName)"
            } catch {
                statusLine = "Skill rejection failed: \(error.localizedDescription)"
            }
        }
    }

    public func learnSkill(source: String, name: String?) {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            statusLine = "Describe the workflow before staging a skill."
            return
        }
        Task {
            guard await ensureBrainReady() else {
                statusLine = "Brain is still starting. Try again in a moment."
                return
            }
            do {
                let report = try await brainClient.learnSkill(
                    source: trimmedSource,
                    name: trimmedName?.isEmpty == false ? trimmedName : nil
                )
                await refreshSkillsAsync()
                selectedSkillDiff = try? await brainClient.pendingSkillDiff(id: report.skillUpdate.id)
                statusLine = report.answer
            } catch {
                statusLine = "Skill learning failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshDashboardAsync() async {
        guard await brainClient.health() else { return }
        async let dashboard = try? brainClient.dashboard()
        async let performance = try? brainClient.performanceStatus()
        async let dictationStatus = try? brainClient.dictationStatus()
        async let prompts = try? brainClient.prompts()
        async let scheduledAgents = try? brainClient.scheduledAgents()
        async let modes = try? brainClient.assistantModes()
        async let capabilities = try? brainClient.capabilities()
        performanceDashboard = await dashboard
        if let report = await performance {
            performanceReport = report
        }
        self.dictationBackendStatus = await dictationStatus
        if let promptReport = await prompts {
            applyPromptReport(promptReport)
        }
        if let agentReport = await scheduledAgents {
            self.scheduledAgents = agentReport.agents
            refreshScheduledAgentStatus()
        }
        if let modeReport = await modes {
            assistantModes = modeReport.modes
            defaultAssistantMode = modeReport.defaultMode
        }
        capabilityReport = await capabilities
    }

    private func configureDictation() {
        dictation.onWillStartRecording = { [weak self] in
            self?.prepareForDictationRecording()
        }
        dictation.onStatusChanged = { [weak self] status in
            guard let self else { return }
            dictationStatus = status
            switch status.phase {
            case .recording, .transcribing:
                phase = .transcribing(status.transcript.isEmpty ? "Dictation" : status.transcript)
            case .formatting:
                phase = .thinking
            case .inserting:
                phase = .acting("Inserting dictation")
            case .inserted, .canceled:
                phase = .idle
            case .error:
                phase = .error(status.message)
            case .idle:
                break
            }
            if status.phase != .idle {
                statusLine = status.message
            }
        }
        dictation.configure(
            DictationConfiguration(
                hotkey: settings.dictation.dictationHotkey.rawValue,
                handsFreeEnabled: settings.dictation.handsFreeDictation,
                sttEngine: settings.dictation.sttEngine.rawValue,
                postProcessing: settings.dictation.postProcessing.rawValue,
                insertAutomatically: settings.dictation.insertAutomatically,
                playSoundFeedback: settings.dictation.playSoundFeedback
            ),
            brainClient: brainClient,
            activeAppNameProvider: { [weak self] in
                self?.targetCapture.captureFrontmostApp().appName
            }
        )
    }

    private func prepareForDictationRecording() {
        flow.cancelTimers()
        flow.clearAwaitingFollowUp()
        pendingFollowUpPrompt = nil
        responseBeingSpoken = nil
        endConversationAfterSpeech = false
        if case .speaking = phase {
            tts.stop()
        }
        if case .listening = phase {
            _ = speech.stop()
        }
        if case .transcribing = phase {
            _ = speech.stop()
        }
        cancelActiveTurn()
        phase = .transcribing("Dictation")
    }

    private func refreshSkillsAsync() async {
        guard await brainClient.health() else { return }
        async let skills = try? brainClient.skills()
        async let pending = try? brainClient.pendingSkillChanges()
        async let bundles = try? brainClient.skillBundles()
        async let history = try? brainClient.skillRunHistory(limit: 20)
        if let report = await skills {
            installedSkills = report.skills
            skillsConfig = report.config
        }
        if let report = await pending {
            pendingSkillChanges = report.changes
            if let selectedSkillDiff, !report.changes.contains(where: { $0.id == selectedSkillDiff.id }) {
                self.selectedSkillDiff = nil
            }
        }
        if let report = await bundles {
            skillBundles = report.bundles
        }
        if let report = await history {
            skillRunHistory = report.runs
        }
    }

    private func refreshScheduledAgentsAsync() async {
        guard await brainClient.health() else { return }
        if let report = try? await brainClient.scheduledAgents() {
            scheduledAgents = report.agents
            refreshScheduledAgentStatus()
        }
    }

    private func refreshSkillRunHistoryAsync() async {
        guard await brainClient.health() else { return }
        if let report = try? await brainClient.skillRunHistory(limit: 20) {
            skillRunHistory = report.runs
        }
    }

    private func captureScheduleContext() async -> ScheduleContext? {
        let schedule = await scheduleContextProvider?()
        latestScheduleContext = schedule
        return schedule
    }

    private func refreshAssistantModesAsync() async {
        guard await brainClient.health() else { return }
        if let report = try? await brainClient.assistantModes() {
            assistantModes = report.modes
            defaultAssistantMode = report.defaultMode
        }
    }

    public func confirm(_ request: ConfirmationRequest) {
        Task {
            phase = .acting(request.title)
            onLocalActionWillExecute?(request.action)
            let response = await actionExecutor.execute(request.action)
            await present(response: response, userText: "confirmed action")
        }
    }

    public func cancelConfirmation() {
        Task {
            await present(
                response: StructuredResponse(answer: "Canceled.", modelUsed: "Local action"),
                userText: "canceled"
            )
        }
    }

    private func startListening() async {
        await startListening(captureTarget: true, followUpPrompt: nil)
    }

    private func startFollowUpListening(prompt: String) async {
        await startListening(captureTarget: false, followUpPrompt: prompt)
    }

    private func startListening(captureTarget: Bool, followUpPrompt: String?) async {
        let currentSnapshot = targetCapture.captureFrontmostApp()
        var isFollowUpTurn = followUpPrompt != nil
        let snapshot: TargetAppSnapshot
        if captureTarget {
            snapshot = currentSnapshot
            session.targetAppSnapshot = snapshot
        } else if let previous = session.targetAppSnapshot,
                  isSameInteractionTarget(previous, currentSnapshot) {
            snapshot = previous
        } else {
            snapshot = currentSnapshot
            session.targetAppSnapshot = snapshot
            isFollowUpTurn = false
            pendingFollowUpPrompt = nil
            flow.clearAwaitingFollowUp()
        }

        flow.beginListening(followUp: isFollowUpTurn)
        lastTranscript = ""
        _ = beginTurn(transcript: "", status: .listening)
        panelController?.show()
        phase = .listening
        let targetStatus = snapshot.windowTitle.map { "Listening in \(snapshot.appName): \($0)" }
            ?? "Listening in \(snapshot.appName)"
        statusLine = isFollowUpTurn ? (followUpPrompt ?? targetStatus) : targetStatus
        let allowed = await speech.requestPermissions()
        guard allowed else {
            flow.clearAwaitingFollowUp()
            failActiveTurn()
            phase = .error("I need microphone and speech recognition access before I can listen.")
            return
        }
        do {
            try speech.start()
            if isFollowUpTurn {
                flow.armFollowUpTimeout()
            }
        } catch {
            flow.clearAwaitingFollowUp()
            failActiveTurn()
            phase = .error(error.localizedDescription)
        }
    }

    private func configureFlow() {
        flow.isVoiceActive = { [weak self] in self?.speech.isVoiceActive ?? false }
        flow.currentTranscript = { [weak self] in
            self?.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        flow.onAutoSubmit = { [weak self] in self?.submitCurrentSpeechTranscript() }
        flow.onFollowUpTimeout = { [weak self] in
            self?.finishConversationAfterNoFollowUp()
        }
    }

    private func configureSpeech() {
        speech.onPartialTranscript = { [weak self] text in
            self?.handleSpeechTranscript(text, isFinal: false)
        }
        speech.onFinalTranscript = { [weak self] text in
            self?.handleSpeechTranscript(text, isFinal: true)
        }
        speech.onVoiceActivity = { [weak self] in
            self?.handleVoiceActivity()
        }
        speech.onError = { [weak self] message in
            guard let self else { return }
            if flow.isSubmitting {
                if isExpectedSpeechCancellation(message) {
                    return
                }
                appendTurnWarning("Speech recognizer returned after submission: \(message)")
                return
            }
            switch phase {
            case .listening, .transcribing:
                if isExpectedSpeechCancellation(message) {
                    return
                }
                failActiveTurn()
                phase = .error(message)
            default:
                appendTurnWarning("Speech recognizer warning: \(message)")
            }
        }
    }

    private func handleSpeechTranscript(_ text: String, isFinal: Bool) {
        guard !flow.isSubmitting else { return }
        lastTranscript = text
        flow.noteTranscriptActivity()
        phase = .transcribing(text)

        if flow.awaitingFollowUp {
            flow.cancelFollowUpTimeout()
            flow.scheduleAutoSubmit()
            return
        }

        runSafePartialCommandIfNeeded(text)
        guard !flow.isSubmitting else { return }
        flow.scheduleAutoSubmit()
    }

    private func handleVoiceActivity() {
        flow.noteVoiceActivity()
    }

    private func configureTTSCallbacks() {
        tts.onPreparing = { [weak self] in
            guard let self else { return }
            if responseBeingSpoken != nil {
                phase = .speaking(voicePreparingPrompt())
            }
        }
        tts.onPlaybackStarted = { [weak self] in
            guard let self, let response = responseBeingSpoken else { return }
            if response.results.isEmpty {
                phase = .speaking(response.answer)
            } else {
                phase = .results(response)
            }
        }
        tts.onPlaybackFailed = { [weak self] message in
            guard let self else { return }
            statusLine = "Voice had a hiccup. Switching voices."
            appendTurnWarning("TTS warning: \(message)")
            print("[JarvisNotch] TTS failed: \(message)")
        }
        tts.onPlaybackFinished = { [weak self] in
            self?.finishSpeechInteraction()
        }
        tts.onDebug = { [weak self] message in
            guard let self else { return }
            ttsDebugLog.append(message)
            if ttsDebugLog.count > 20 {
                ttsDebugLog.removeFirst(ttsDebugLog.count - 20)
            }
        }
    }

    private func runSafePartialCommandIfNeeded(_ text: String) {
        let normalized = commandMatcher.normalize(text)
        guard ["pause", "stop", "cancel", "skip", "mute"].contains(normalized) else {
            return
        }
        if case .handled(_, let action?) = commandMatcher.match(normalized, shortcuts: settings.shortcuts) {
            Task {
                flow.markSubmitted()
                _ = speech.stop()
                onLocalActionWillExecute?(action)
                let response = await actionExecutor.execute(action)
                await present(response: response, userText: normalized)
            }
        }
    }

    private func submitCurrentSpeechTranscript() {
        let transcript = speech.stop()
        let fallback = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        submitTranscript(transcript.isEmpty ? fallback : transcript)
    }

    private func submitTranscript(_ transcript: String) {
        guard !flow.isSubmitting else { return }
        flow.markSubmitted()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            flow.clearAwaitingFollowUp()
            cancelActiveTurn()
            phase = .idle
            panelController?.hide()
            return
        }

        if flow.awaitingFollowUp {
            flow.clearAwaitingFollowUp()
        }

        if FollowUpPhrases.isDone(text) {
            Task { await finishConversationAfterDoneReply(userText: text) }
            return
        }

        let turnID = activeTurn?.id ?? beginTurn(transcript: text, status: .routing)
        updateActiveTurn(turnID, status: .routing, transcript: text)
        Task { await processTranscript(text, turnID: turnID) }
    }

    private func refreshBrainAfterSettingsChange(message: String, testProvider: ProviderID? = nil) {
        Task {
            brainReady = false
            brainProcess.restart(settings: settings)
            brainReady = await waitForBrainReady()
            guard brainReady else {
                statusLine = "\(message). Local commands are ready while I reconnect."
                return
            }
            await syncPromptSettingsToBrain()
            if let testProvider {
                do {
                    let report = try await brainClient.testProviders()
                    statusLine = providerStatusLine(from: report, preferredProvider: testProvider)
                    await refreshRuntimeStatus()
                } catch {
                    statusLine = "\(message). Brain ready, but provider test failed."
                }
            } else {
                statusLine = "\(message). Brain ready."
                await refreshRuntimeStatus()
            }
        }
    }

    private func ensureBrainReady() async -> Bool {
        if await brainClient.health() {
            brainReady = true
            return true
        }
        brainReady = false
        brainProcess.startIfNeeded(settings: settings)
        if await waitForBrainReady(attempts: 16) {
            brainReady = true
            return true
        }
        brainProcess.restart(settings: settings)
        brainReady = await waitForBrainReady(attempts: 24)
        return brainReady
    }

    private func waitForBrainReady(attempts: Int = 48) async -> Bool {
        for attempt in 0..<attempts {
            if await brainClient.health() {
                return true
            }
            if attempt < attempts - 1 {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        return false
    }

    private func processTranscript(_ transcript: String, turnID: UUID) async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            cancelActiveTurn()
            phase = .idle
            panelController?.hide()
            return
        }
        guard updateActiveTurn(turnID, status: .routing, transcript: text) else { return }

        lastTranscript = text
        phase = .thinking
        statusLine = text
        guard updateActiveTurn(turnID, status: .collectingContext) else { return }
        let targetChanged = refreshTargetSnapshotForCurrentAskIfNeeded()
        let previousContext = session.lastScreenContext
        var context = contextBuilder.buildContext(
            target: session.targetAppSnapshot,
            settings: contextSettings(for: text)
        )
        context.schedule = await captureScheduleContext()
        if shouldStartFreshSession(
            previous: previousContext,
            current: context,
            targetChanged: targetChanged,
            transcript: text
        ) {
            let target = session.targetAppSnapshot
            session.clear(timeoutMinutes: settings.session.idleTimeoutMinutes)
            session.targetAppSnapshot = target
        }
        session.lastScreenContext = context

        if settings.session.followUpContextEnabled {
            let followUp = followUpResolver.resolve(text, session: session)
            switch followUp {
            case .action(let action, let selected):
                session.lastSelectedEntity = selected
                await handle(action: action, userText: text, turnID: turnID)
                return
            case .compare(let results):
                await askBrain(text, context: context, injectedResults: results, mode: "smart", turnID: turnID)
                return
            case .expired:
                await present(
                    response: StructuredResponse(
                        answer: "I don't have that result set active anymore. Want me to search again?",
                        modelUsed: "Session",
                        metadata: ResponseMetadata(route: "session")
                    ),
                    userText: text,
                    turnID: turnID
                )
                return
            case .needsBrain, .notFollowUp:
                break
            }
        }

        if intentRouter.prefersCloudAgent(text) {
            await routeEscalatedRequest(text, context: context, localReason: "User requested the cloud agent.", turnID: turnID)
            return
        }

        switch commandMatcher.match(text, shortcuts: settings.shortcuts) {
        case .handled(let response, let action):
            if let action {
                await handle(action: action, userText: text, turnID: turnID)
            } else {
                await present(
                    response: StructuredResponse(
                        answer: response ?? "Done.",
                        modelUsed: "Local command",
                        metadata: ResponseMetadata(route: "direct_command")
                    ),
                    userText: text,
                    turnID: turnID
                )
            }
        case .needsConfirmation(let request):
            phase = .confirming(request)
        case .notMatched:
            switch localAnswerRouter.answer(text, context: context) {
            case .answer(let answer):
                await present(
                    response: StructuredResponse(
                        answer: answer,
                        modelUsed: "Local answer",
                        metadata: ResponseMetadata(
                            route: "local_deterministic",
                            contextAvailable: context.hasAnyText || context.hasScheduleContext
                        )
                    ),
                    userText: text,
                    turnID: turnID
                )
            case .escalate(let reason):
                await routeEscalatedRequest(text, context: context, localReason: reason, turnID: turnID)
            }
        }
    }

    private func routeEscalatedRequest(_ text: String, context: ContextPacket?, localReason: String, turnID: UUID) async {
        if let pageReadError = contextFailureMessage(for: text, context: context) {
            await present(
                response: StructuredResponse(
                    answer: pageReadError,
                    speak: "I couldn't read that context yet.",
                    modelUsed: "Browser context",
                    metadata: ResponseMetadata(
                        route: "context_missing",
                        usedScreenContext: false,
                        contextAvailable: false,
                        warnings: [pageReadError]
                    )
                ),
                userText: text,
                turnID: turnID
            )
            return
        }

        if await shouldTryAppleLocalAnswer(text, localReason: localReason, context: context) {
            switch await localModel.answer(text, context: localModelContext(for: text, context: context)) {
            case .answer(let answer):
                await present(
                    response: StructuredResponse(
                        answer: answer,
                        modelUsed: "Apple Foundation Model",
                        metadata: ResponseMetadata(
                            route: "local_foundation_model",
                            usedScreenContext: context?.hasScreenOrBrowserText == true,
                            contextAvailable: context?.hasAnyText == true || context?.hasScheduleContext == true
                        )
                    ),
                    userText: text,
                    turnID: turnID
                )
                return
            case .unavailable(let message), .failed(let message):
                appendTurnWarning(message)
            }
        }
        await askBrain(
            text,
            context: context,
            mode: brainMode(for: text, context: context).rawValue,
            allowLocalFallback: !intentRouter.prefersCloudAgent(text),
            turnID: turnID
        )
    }

    private func askBrain(
        _ text: String,
        context: ContextPacket?,
        injectedResults: [StructuredResult] = [],
        mode: String? = nil,
        allowLocalFallback: Bool = true,
        turnID: UUID? = nil
    ) async {
        if let turnID {
            guard updateActiveTurn(turnID, status: .callingBrain) else { return }
        }
        guard await ensureBrainReady() else {
            if allowLocalFallback,
               let fallback = await localFallbackResponse(for: text, context: context, warning: "Local brain is still starting.") {
                await present(response: fallback, userText: text, turnID: turnID)
                return
            }
            await present(
                response: StructuredResponse(
                    answer: "My local brain is still starting. Try that again in a moment.",
                    speak: "My local brain is still starting.",
                    modelUsed: "Local brain",
                    metadata: ResponseMetadata(route: "brain_unavailable")
                ),
                userText: text,
                turnID: turnID
            )
            return
        }
        if let turnID, !isActiveTurn(turnID) { return }

        var requestSession = session
        if !injectedResults.isEmpty {
            requestSession.lastResults = injectedResults
        }
        let request = BrainChatRequest(
            message: text,
            conversationId: requestSession.currentConversationId,
            context: context,
            session: requestSession,
            mode: mode ?? brainMode(for: text, context: context).rawValue,
            intent: routedIntent(for: text, context: context).rawValue,
            requiresScreenContext: requiresScreenContext(text, context: context)
        )

        do {
            let response = try await brainClient.chat(request)
            if allowLocalFallback,
               shouldUseLocalFallback(for: response),
               let fallback = await localFallbackResponse(
                    for: text,
                    context: context,
                    warning: "Cloud/provider route was \(response.metadata.route ?? "unavailable")."
               ) {
                await present(response: fallback, userText: text, turnID: turnID)
                return
            }
            await present(response: response, userText: text, turnID: turnID)
        } catch {
            appendTurnWarning("Brain request failed: \(error.localizedDescription)")
            if allowLocalFallback,
               let fallback = await localFallbackResponse(for: text, context: context, warning: error.localizedDescription) {
                await present(response: fallback, userText: text, turnID: turnID)
                return
            }
            await present(
                response: StructuredResponse(
                    answer: "I’m having trouble reaching my local brain. Local commands still work while I reconnect.",
                    speak: "I’m having trouble reaching my local brain.",
                    modelUsed: "Local brain",
                    metadata: ResponseMetadata(route: "brain_unavailable", warnings: [error.localizedDescription])
                ),
                userText: text,
                turnID: turnID
            )
        }
    }

    private func handle(action: AssistantAction, userText: String, turnID: UUID? = nil) async {
        if let confirmation = actionRegistry.confirmation(for: action) {
            phase = .confirming(confirmation)
            return
        }
        if let turnID, !updateActiveTurn(turnID, status: .routing) { return }
        phase = .acting(action.type)
        onLocalActionWillExecute?(action)
        let response = await actionExecutor.execute(action)
        await present(response: response, userText: userText, turnID: turnID)
    }

    private func present(response: StructuredResponse, userText: String, turnID: UUID? = nil) async {
        if let turnID, !isActiveTurn(turnID) { return }
        var finalResponse = userFacing(response)
        var executedActionResponses: [StructuredResponse] = []

        if let confirmation = response.confirmation ?? response.actions.compactMap(actionRegistry.confirmation(for:)).first {
            phase = .confirming(confirmation)
            return
        }

        for action in response.actions where actionRegistry.risk(for: action) == .green {
            onLocalActionWillExecute?(action)
            let actionResponse = userFacing(await actionExecutor.execute(action))
            executedActionResponses.append(actionResponse)
            if let turnID, !isActiveTurn(turnID) { return }
            if finalResponse.answer.isEmpty {
                finalResponse.answer = actionResponse.answer
            }
            if finalResponse.speak.isEmpty {
                finalResponse.speak = actionResponse.speak
            }
        }

        let composed = responseComposer.compose(
            response: finalResponse,
            userText: userText,
            settings: settings,
            executedActions: executedActionResponses
        )
        finalResponse = userFacing(composed.response)

        session.record(user: userText, response: finalResponse, timeoutMinutes: settings.session.idleTimeoutMinutes)
        if let first = finalResponse.results.first {
            session.lastSelectedEntity = first
        }
        if !finalResponse.skillUpdates.isEmpty {
            await refreshSkillsAsync()
        } else if finalResponse.metadata.selectedSkill != nil || finalResponse.metadata.selectedBundle != nil {
            await refreshSkillRunHistoryAsync()
        }

        modelBadgeText = finalResponse.metadata.model ?? finalResponse.modelUsed ?? finalResponse.metadata.route ?? "Jarvis"
        let followUpPlan = nextFollowUpPlan(response: finalResponse)
        pendingFollowUpPrompt = followUpPlan.listeningPrompt
        let spokenText = spokenText(for: finalResponse.speak, followUpPrompt: followUpPlan.spokenPrompt)
        responseBeingSpoken = finalResponse
        if let turnID {
            _ = updateActiveTurn(turnID, status: .speaking)
        }
        phase = .speaking(voicePreparingPrompt())
        tts.speak(spokenText, limit: spokenText.count, style: composed.voiceStyle)
    }

    private func finishSpeechInteraction() {
        guard responseBeingSpoken != nil else { return }
        responseBeingSpoken = nil
        let prompt = pendingFollowUpPrompt
        pendingFollowUpPrompt = nil
        completeActiveTurn()
        if endConversationAfterSpeech {
            endConversationAfterSpeech = false
            statusLine = "Ready when you are"
            phase = .idle
            panelController?.hide()
            return
        }
        guard !isInteractivePhase else { return }
        guard let prompt else {
            statusLine = "Ready when you are"
            phase = .idle
            panelController?.hide()
            return
        }
        Task { await startFollowUpListening(prompt: prompt) }
    }

    private var isInteractivePhase: Bool {
        switch phase {
        case .listening, .transcribing, .thinking, .acting, .confirming:
            true
        case .idle, .speaking, .results, .error:
            false
        }
    }

    private func voicePreparingPrompt() -> String {
        let prompts = [
            "One sec.",
            "Got it.",
            "Almost there.",
            "Let me put that together."
        ]
        return prompts[Int.random(in: 0..<prompts.count)]
    }

    private func fallbackFollowUpPrompt() -> String {
        let prompts = [
            "Need anything else?",
            "Want me to keep going?",
            "What should we tackle next?",
            "I’m here. Next move?",
            "Anything you want me to open up?",
            "Want a follow-up on that?"
        ]
        let choices = prompts.filter { $0 != lastFollowUpPrompt }
        let selected = choices.randomElement() ?? prompts[0]
        lastFollowUpPrompt = selected
        return selected
    }

    private func nextFollowUpPlan(response: StructuredResponse) -> FollowUpPromptPlan {
        guard settings.session.followUpContextEnabled else {
            return FollowUpPromptPlan(spokenPrompt: nil, listeningPrompt: nil)
        }
        if response.metadata.route == "direct_command", response.results.isEmpty {
            return FollowUpPromptPlan(spokenPrompt: nil, listeningPrompt: nil)
        }
        if response.metadata.route == "scheduled_agent" {
            return FollowUpPromptPlan(spokenPrompt: nil, listeningPrompt: nil)
        }

        let answerText = "\(response.answer) \(response.speak)"
        if AssistantTextInspector.containsQuestion(answerText) {
            return FollowUpPromptPlan(spokenPrompt: nil, listeningPrompt: "Listening for your answer...")
        }

        let prompt = fallbackFollowUpPrompt()
        return FollowUpPromptPlan(spokenPrompt: prompt, listeningPrompt: prompt)
    }

    private func spokenText(for answer: String, followUpPrompt: String?) -> String {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = followUpPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else { return ResponseComposer.sanitizeSpokenText(trimmedAnswer) }
        guard !trimmedAnswer.isEmpty else { return prompt }

        let promptBudget = prompt.count + 1
        let answerBudget = max(80, settings.voice.spokenSummaryLimit - promptBudget)
        let clippedAnswer = trimmedAnswer.count > answerBudget
            ? String(trimmedAnswer.prefix(answerBudget))
            : trimmedAnswer
        return ResponseComposer.sanitizeSpokenText("\(clippedAnswer) \(prompt)")
    }

    private func isExpectedSpeechCancellation(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("recognition request was canceled")
            || lower.contains("recognition request was cancelled")
            || lower == "canceled"
            || lower == "cancelled"
    }

    private func finishConversationAfterDoneReply(userText: String = "done") async {
        flow.cancelTimers()
        _ = speech.stop()
        flow.clearAwaitingFollowUp()
        pendingFollowUpPrompt = nil
        let closing = fallbackClosingReply()
        let response = StructuredResponse(
            answer: closing,
            speak: closing,
            modelUsed: "Local conversation",
            metadata: ResponseMetadata(route: "local_conversation")
        )
        if let turnID = activeTurn?.id {
            _ = updateActiveTurn(turnID, status: .speaking, transcript: userText)
        }
        responseBeingSpoken = response
        endConversationAfterSpeech = true
        statusLine = closing
        phase = .speaking(closing)
        tts.speak(closing, limit: 80, style: VoiceStyle.style(for: .quick, spokenLimit: 80))
    }

    private func finishConversationAfterNoFollowUp() {
        flow.cancelTimers()
        _ = speech.stop()
        flow.clearAwaitingFollowUp()
        pendingFollowUpPrompt = nil
        responseBeingSpoken = nil
        endConversationAfterSpeech = false
        cancelActiveTurn()
        statusLine = "Ready when you are"
        phase = .idle
        panelController?.hide()
    }

    private func fallbackClosingReply() -> String {
        let replies = [
            "No problem.",
            "Anytime.",
            "You got it.",
            "All set.",
            "Of course."
        ]
        return replies.randomElement() ?? "No problem."
    }

    private func providerStatusLine(from report: ProviderTestReport, preferredProvider: ProviderID?) -> String {
        let providerKey = preferredProvider?.rawValue ?? report.enabled.first
        guard let providerKey else {
            return "No provider keys are configured yet."
        }
        guard let result = report.results[providerKey] else {
            return "\(displayName(for: providerKey)) key is saved, but the provider was not tested."
        }
        let modelSuffix = result.model.map { " using \($0)" } ?? ""
        if result.ok {
            return "\(displayName(for: providerKey)) connected\(modelSuffix)."
        }
        return "\(displayName(for: providerKey)) did not connect\(modelSuffix): \(result.message)"
    }

    private func displayName(for providerKey: String) -> String {
        ProviderID(rawValue: providerKey)?.displayName ?? providerKey.capitalized
    }

    private func refreshKeyPresence() {
        providerKeyPresence = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { provider in
            (provider, keychain.hasAPIKey(for: provider))
        })
    }

    private func enableProviderForSavedKey(_ provider: ProviderID) {
        for index in settings.providers.indices {
            if settings.providers[index].id == provider {
                settings.providers[index].enabled = true
            }
        }
        settings.providerFallbackOrder.removeAll { $0 == provider }
        settings.providerFallbackOrder.insert(provider, at: 0)
    }

    private func refreshRuntimeStatus() async {
        guard await brainClient.health() else { return }
        async let diagnostics = try? brainClient.providerDiagnostics()
        async let memory = try? brainClient.memoryStatus()
        async let tts = try? brainClient.ttsStatus()
        async let fileIndex = try? fileIndexClient().status()
        async let dashboard = try? brainClient.dashboard()
        async let performance = try? brainClient.performanceStatus()
        async let skills = try? brainClient.skills()
        async let pending = try? brainClient.pendingSkillChanges()
        async let bundles = try? brainClient.skillBundles()
        async let dictationStatus = try? brainClient.dictationStatus()
        async let prompts = try? brainClient.prompts()
        async let scheduledAgents = try? brainClient.scheduledAgents()
        async let modes = try? brainClient.assistantModes()
        async let capabilities = try? brainClient.capabilities()
        providerDiagnostics = await diagnostics
        memoryStatus = await memory
        ttsStatus = await tts
        fileIndexStatus = await fileIndex
        performanceDashboard = await dashboard
        performanceReport = await performance
        if let report = await skills {
            installedSkills = report.skills
            skillsConfig = report.config
        }
        if let report = await pending {
            pendingSkillChanges = report.changes
        }
        if let report = await bundles {
            skillBundles = report.bundles
        }
        dictationBackendStatus = await dictationStatus
        if let promptReport = await prompts {
            applyPromptReport(promptReport)
        }
        if let agentReport = await scheduledAgents {
            self.scheduledAgents = agentReport.agents
            refreshScheduledAgentStatus()
        }
        if let modeReport = await modes {
            assistantModes = modeReport.modes
            defaultAssistantMode = modeReport.defaultMode
        }
        capabilityReport = await capabilities
    }

    private func replaceScheduledAgent(_ agent: ScheduledAgent) {
        if let index = scheduledAgents.firstIndex(where: { $0.id == agent.id }) {
            scheduledAgents[index] = agent
        } else {
            scheduledAgents.append(agent)
        }
    }

    private var activeScheduledAgents: [ScheduledAgent] {
        scheduledAgents.filter { $0.enabled && $0.type == "scheduled" }
    }

    private var canRunScheduledAgentNow: Bool {
        switch phase {
        case .idle, .results:
            true
        case .listening, .transcribing, .thinking, .acting, .speaking, .confirming, .error:
            false
        }
    }

    private func restartScheduledAgentLoop() {
        if scheduledAgentRunInProgress {
            refreshScheduledAgentStatus()
            return
        }

        scheduledAgentTask?.cancel()
        scheduledAgentTask = nil

        let activeAgents = activeScheduledAgents
        guard !activeAgents.isEmpty else {
            scheduledAgentStatus = "No active scheduled agents"
            return
        }

        scheduledAgentStatus = scheduledAgentStatusLine(for: activeAgents)
        scheduledAgentTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runDueScheduledAgents()
                do {
                    try await Task.sleep(nanoseconds: Self.scheduledAgentPollIntervalNanoseconds)
                } catch {
                    break
                }
            }
        }
    }

    private func refreshScheduledAgentStatus() {
        scheduledAgentStatus = scheduledAgentStatusLine(for: activeScheduledAgents)
    }

    private func scheduledAgentStatusLine(for agents: [ScheduledAgent]) -> String {
        guard !agents.isEmpty else { return "No active scheduled agents" }
        if agents.count == 1, let agent = agents.first {
            if let next = agent.nextRunAt, !next.isEmpty {
                return "\(agent.name) active. Next run: \(next)"
            }
            return "\(agent.name) active"
        }
        return "\(agents.count) scheduled agents active"
    }

    private func runDueScheduledAgents() async {
        guard brainReady else {
            scheduledAgentStatus = "Scheduled agents waiting for brain"
            return
        }
        guard !scheduledAgentRunInProgress else { return }

        let dueAgents = activeScheduledAgents.filter { $0.isDue() }
        guard !dueAgents.isEmpty else {
            refreshScheduledAgentStatus()
            return
        }
        guard canRunScheduledAgentNow else {
            scheduledAgentStatus = "Scheduled agents waiting until Jarvis is idle"
            return
        }

        scheduledAgentRunInProgress = true
        defer {
            scheduledAgentRunInProgress = false
            refreshScheduledAgentStatus()
        }

        for agent in dueAgents {
            guard !Task.isCancelled else { return }
            await runScheduledAgent(agent)
        }
    }

    private func runScheduledAgent(_ agent: ScheduledAgent) async {
        let runAt = Date()
        scheduledAgentStatus = "Running \(agent.name)"
        statusLine = "Running \(agent.name)"

        do {
            let schedule = await captureScheduleContext()
            let preview = try await brainClient.previewScheduledAgent(id: agent.id, schedule: schedule)
            let updated = try await brainClient.recordScheduledAgentRun(id: agent.id, runAt: runAt)
            replaceScheduledAgent(updated)

            scheduledAgentPreview = preview
            lastScheduledAgentRun = preview
            lastScheduledAgentRunAt = runAt

            let metadata = preview.metadata ?? ResponseMetadata(
                route: "scheduled_agent",
                modelRoute: "local_skill",
                mode: agent.id,
                contextAvailable: schedule?.hasAnyEntries == true
            )
            let response = StructuredResponse(
                answer: preview.answer,
                speak: preview.speak,
                modelUsed: agent.name,
                metadata: metadata
            )
            panelController?.show()
            await present(response: response, userText: "scheduled \(agent.name)")
            scheduledAgentStatus = "Last ran \(agent.name) at \(runAt.formatted(date: .abbreviated, time: .shortened))"
        } catch {
            scheduledAgentStatus = "\(agent.name) failed: \(error.localizedDescription)"
            statusLine = scheduledAgentStatus
        }
    }

    private func syncPromptSettingsToBrain() async {
        guard await brainClient.health() else { return }
        do {
            let report = try await brainClient.savePrompts(promptReportsFromSettings())
            applyPromptReport(report)
        } catch {
            statusLine = "Prompt sync failed: \(error.localizedDescription)"
        }
    }

    private func applyPromptReport(_ report: PromptListReport) {
        editablePrompts = report.prompts
        for prompt in report.prompts {
            switch prompt.id {
            case "assistant":
                settings.prompts.assistantPrompt = prompt.content
            case "dictation":
                settings.dictation.dictationPrompt = prompt.content
            case "email":
                settings.dictation.emailPrompt = prompt.content
            case "writing_style":
                settings.dictation.writingStylePrompt = prompt.content
            case "skill_learning":
                settings.prompts.skillLearningPrompt = prompt.content
            case "command_interpretation":
                settings.prompts.commandInterpretationPrompt = prompt.content
            default:
                break
            }
        }
    }

    private func applyPromptSettingsToLocalReports() {
        editablePrompts = promptReportsFromSettings()
    }

    private func promptReportsFromSettings() -> [JarvisPrompt] {
        [
            promptReport(
                id: "assistant",
                title: "Assistant Prompt",
                description: "Default assistant behavior, tone, and context rules.",
                content: settings.prompts.assistantPrompt
            ),
            promptReport(
                id: "dictation",
                title: "Dictation Cleanup Prompt",
                description: "How dictated speech should be cleaned before insertion.",
                content: settings.dictation.dictationPrompt
            ),
            promptReport(
                id: "email",
                title: "Email Formatting Prompt",
                description: "How email drafts and dictated email text should be formatted.",
                content: settings.dictation.emailPrompt
            ),
            promptReport(
                id: "writing_style",
                title: "Writing Style Prompt",
                description: "Personal writing preferences to apply when editing or drafting.",
                content: settings.dictation.writingStylePrompt
            ),
            promptReport(
                id: "skill_learning",
                title: "Skill Learning Prompt",
                description: "How Jarvis drafts reusable SKILL.md procedures.",
                content: settings.prompts.skillLearningPrompt
            ),
            promptReport(
                id: "command_interpretation",
                title: "Command Interpretation Prompt",
                description: "How natural requests are mapped to modes, skills, and actions.",
                content: settings.prompts.commandInterpretationPrompt
            )
        ]
    }

    private func promptReport(id: String, title: String, description: String, content: String) -> JarvisPrompt {
        if var existing = editablePrompts.first(where: { $0.id == id }) {
            existing.content = content
            return existing
        }
        return JarvisPrompt(
            id: id,
            title: title,
            description: description,
            content: content,
            source: "local",
            editable: true,
            path: nil
        )
    }

    private func fileIndexClient() -> FileIndexClient {
        FileIndexClient(baseURL: brainClient.baseURL, token: brainClient.token)
    }

    private func refreshTargetSnapshotForCurrentAskIfNeeded() -> Bool {
        let current = targetCapture.captureFrontmostApp()
        guard !isJarvisTarget(current) else { return false }
        guard let previous = session.targetAppSnapshot else {
            session.targetAppSnapshot = current
            return true
        }
        guard !isSameInteractionTarget(previous, current) else { return false }
        session.targetAppSnapshot = current
        return true
    }

    private func shouldStartFreshSession(
        previous: ContextPacket?,
        current: ContextPacket,
        targetChanged: Bool,
        transcript: String
    ) -> Bool {
        guard previous != nil else { return false }
        if preservesResultFollowUpDespiteTargetChange(transcript) {
            return false
        }
        if targetChanged {
            return true
        }
        return contextSignature(previous) != contextSignature(current)
    }

    private func contextSignature(_ context: ContextPacket?) -> String {
        guard let context else { return "" }
        let target = context.targetApp
        let app = target?.bundleIdentifier ?? target?.appName ?? context.frontmostApp ?? ""
        let window = normalizedWindowTitle(target?.windowTitle ?? context.accessibility?.windowTitle)
        let url = context.browser?.url?.absoluteString ?? ""
        let title = context.browser?.title ?? ""
        if !url.isEmpty {
            return "\(app)|\(url)"
        }
        return "\(app)|\(window)|\(title)"
    }

    private func isSameInteractionTarget(_ lhs: TargetAppSnapshot, _ rhs: TargetAppSnapshot) -> Bool {
        if isJarvisTarget(rhs) { return true }
        let lhsApp = lhs.bundleIdentifier ?? lhs.appName
        let rhsApp = rhs.bundleIdentifier ?? rhs.appName
        guard lhsApp == rhsApp else { return false }
        let lhsWindow = normalizedWindowTitle(lhs.windowTitle)
        let rhsWindow = normalizedWindowTitle(rhs.windowTitle)
        if !lhsWindow.isEmpty, !rhsWindow.isEmpty {
            return lhsWindow == rhsWindow
        }
        return lhs.processIdentifier == rhs.processIdentifier || lhs.appName == rhs.appName
    }

    private func isJarvisTarget(_ snapshot: TargetAppSnapshot) -> Bool {
        let haystack = "\(snapshot.appName) \(snapshot.bundleIdentifier ?? "")".lowercased()
        return haystack.contains("jarvis")
    }

    private func normalizedWindowTitle(_ title: String?) -> String {
        (title ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func preservesResultFollowUpDespiteTargetChange(_ transcript: String) -> Bool {
        let lower = transcript.lowercased()
        guard !session.lastResults.isEmpty || !session.lastOpenedURLs.isEmpty else { return false }
        if lower.contains("open") || lower.contains("compare") {
            return true
        }
        let resultWords = ["first", "second", "third", "fourth", "fifth", "1st", "2nd", "3rd", "4th", "5th"]
        return resultWords.contains { lower.contains($0) }
    }

    private func routedIntent(for text: String, context: ContextPacket?) -> RoutedIntent {
        let routed = intentRouter.classify(text)
        if routed == .general, shouldTreatAsSelectedTextRequest(text, context: context) {
            return .screenContext
        }
        return routed
    }

    private func requiresScreenContext(_ text: String, context: ContextPacket?) -> Bool {
        intentRouter.requiresScreenContext(text) || shouldTreatAsSelectedTextRequest(text, context: context)
    }

    private func shouldTreatAsSelectedTextRequest(_ text: String, context: ContextPacket?) -> Bool {
        guard hasSelectedText(context) else { return false }
        if intentRouter.referencesSelectedOrHighlightedText(text) {
            return true
        }
        let lower = text.lowercased()
        let deicticPhrases = [
            "this",
            "that",
            "it",
            "what does",
            "what is",
            "who is",
            "explain",
            "summarize",
            "rewrite",
            "translate"
        ]
        return deicticPhrases.contains { lower.contains($0) }
    }

    private func hasSelectedText(_ context: ContextPacket?) -> Bool {
        let selected = context?.selectedText ?? context?.browser?.selectedText ?? ""
        return !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func contextSettings(for text: String) -> ContextSettings {
        if intentRouter.referencesSelectedOrHighlightedText(text) {
            return selectedTextContextSettings()
        }
        if intentRouter.requiresScreenContext(text) {
            return screenContextSettings()
        }
        return lightContextSettings()
    }

    private func lightContextSettings() -> ContextSettings {
        var resolved = settings.context
        resolved.selectedTextAccessEnabled = settings.context.selectedTextAccessEnabled
        resolved.accessibilityAccessEnabled = false
        resolved.browserReaderEnabled = false
        resolved.wordContextEnabled = settings.context.wordContextEnabled
        resolved.fileIndexEnabled = false
        resolved.memoryContextEnabled = false
        resolved.allowCloudFileContents = false
        return resolved
    }

    private func selectedTextContextSettings() -> ContextSettings {
        var resolved = lightContextSettings()
        resolved.selectedTextAccessEnabled = settings.context.selectedTextAccessEnabled
        resolved.wordContextEnabled = settings.context.wordContextEnabled
        return resolved
    }

    private func screenContextSettings() -> ContextSettings {
        var resolved = settings.context
        resolved.fileIndexEnabled = false
        resolved.memoryContextEnabled = false
        resolved.allowCloudFileContents = false
        return resolved
    }

    private func localModelContext(for text: String, context: ContextPacket?) -> ContextPacket? {
        if requiresScreenContext(text, context: context) || isScheduleQuestion(text) {
            return context
        }
        if context?.hasDocumentContext == true || hasSelectedText(context) {
            return context
        }
        return nil
    }

    private func contextFailureMessage(for text: String, context: ContextPacket?) -> String? {
        guard requiresScreenContext(text, context: context) else {
            return nil
        }
        if context?.hasScreenOrBrowserText == true {
            return nil
        }
        if isScheduleQuestion(text), context?.hasScheduleContext == true {
            return nil
        }
        if let error = context?.browserError {
            return error.message
        }
        if let target = context?.targetApp {
            return "I captured \(target.appName), but I couldn't read any page, selected, or visible text from it yet."
        }
        return "I couldn't capture readable screen or browser context yet."
    }

    private func isScheduleQuestion(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("calendar")
            || lower.contains("reminder")
            || lower.contains("schedule")
            || lower.contains("meeting")
            || lower.contains("appointment")
            || lower.contains("event")
    }

    private func brainMode(for text: String, context: ContextPacket?) -> BrainMode {
        intentRouter.mode(for: text, hasBrowserContext: context?.browser != nil)
    }

    /// Whether to attempt an answer from Apple's on-device model before falling
    /// back to the cloud brain. Provider-backed answers remain the fallback for
    /// web, memory, unavailable local models, and requests that need deeper tools.
    private func shouldTryAppleLocalAnswer(_ text: String, localReason: String, context: ContextPacket?) async -> Bool {
        if intentRouter.prefersCloudAgent(text) { return false }
        if localReason.lowercased().contains("memory") { return false }
        return await canUseAppleLocalModel(for: text, context: context, allowWeb: false)
    }

    private func shouldUseLocalFallback(for response: StructuredResponse) -> Bool {
        switch response.metadata.route {
        case "missing_provider", "provider_failed", "provider_dependency_missing":
            return true
        default:
            return false
        }
    }

    private func localFallbackResponse(for text: String, context: ContextPacket?, warning: String) async -> StructuredResponse? {
        guard await canUseAppleLocalModel(for: text, context: context, allowWeb: true) else {
            return nil
        }
        switch await localModel.answer(text, context: localModelContext(for: text, context: context)) {
        case .answer(let answer):
            return StructuredResponse(
                answer: answer,
                modelUsed: "Apple Foundation Model",
                metadata: ResponseMetadata(
                    route: "local_foundation_model",
                    usedScreenContext: context?.hasScreenOrBrowserText == true,
                    contextAvailable: context?.hasAnyText == true || context?.hasScheduleContext == true,
                    warnings: [warning]
                )
            )
        case .unavailable(let message), .failed(let message):
            appendTurnWarning(message)
            return nil
        }
    }

    private func canUseAppleLocalModel(for text: String, context: ContextPacket?, allowWeb: Bool) async -> Bool {
        if intentRouter.prefersCloudAgent(text) { return false }
        var intent = await intentClassifier.classifyIntent(text)
        if intent == .general, shouldTreatAsSelectedTextRequest(text, context: context) {
            intent = .screenContext
        }

        switch intent {
        case .action, .memory:
            return false
        case .web:
            return allowWeb
        case .screenContext:
            return context?.hasScreenOrBrowserText == true || context?.hasScheduleContext == true
        case .compare, .general:
            return true
        }
    }

    private func userFacing(_ response: StructuredResponse) -> StructuredResponse {
        var cleaned = response
        cleaned.answer = cleanAssistantText(cleaned.answer)
        cleaned.speak = ResponseComposer.sanitizeSpokenText(cleanAssistantText(cleaned.speak))
        if cleaned.metadata.route == nil {
            cleaned.metadata.route = inferredRoute(from: cleaned.modelUsed)
        }
        if cleaned.metadata.contextAvailable == false {
            cleaned.metadata.contextAvailable = session.lastScreenContext?.hasAnyText == true
                || session.lastScreenContext?.hasScheduleContext == true
        }
        if cleaned.metadata.ttsEngine == nil {
            cleaned.metadata.ttsEngine = settings.voice.ttsEngine.rawValue
        }
        let warnings = turnWarnings + cleaned.metadata.warnings
        cleaned.metadata.warnings = Array(NSOrderedSet(array: warnings).compactMap { $0 as? String })
        if cleaned.speak.isEmpty {
            cleaned.speak = cleaned.answer
        }
        if cleaned.answer.isEmpty {
            cleaned.answer = "I got tangled up there. Try that again?"
            cleaned.speak = "Try that again?"
        }
        return cleaned
    }

    private func inferredRoute(from modelUsed: String?) -> String? {
        guard let modelUsed else { return nil }
        let lower = modelUsed.lowercased()
        if lower.contains("local command") || lower.contains("local action") {
            return "direct_command"
        }
        if lower.contains("local answer") {
            return "local_deterministic"
        }
        if lower.contains("foundation") {
            return "local_foundation_model"
        }
        if lower.contains("memory") {
            return "memory"
        }
        if lower.contains("openai") || lower.contains("anthropic") || lower.contains("gemini") {
            return "cloud_llm"
        }
        return nil
    }

    private func cleanAssistantText(_ text: String) -> String {
        var result = text
        while let start = result.range(of: "<untrusted_context>"),
              let end = result.range(of: "</untrusted_context>"),
              start.lowerBound < end.upperBound {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }

        let filteredLines = result
            .components(separatedBy: .newlines)
            .filter { line in
                let lower = line.lowercased()
                return !lower.contains("untrusted user-screen")
                    && !lower.contains("untrusted context")
                    && !lower.contains("use it only as reference material")
            }

        return filteredLines
            .joined(separator: "\n")
            .replacingOccurrences(of: "You asked:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func beginTurn(transcript: String, status: TurnStatus) -> UUID {
        let turn = AssistantTurn(transcript: transcript, status: status)
        activeTurn = turn
        turnWarnings = []
        return turn.id
    }

    @discardableResult
    private func updateActiveTurn(_ id: UUID, status: TurnStatus, transcript: String? = nil) -> Bool {
        guard var turn = activeTurn, turn.id == id else {
            return false
        }
        if let transcript {
            turn.transcript = transcript
        }
        turn.status = status
        activeTurn = turn
        return true
    }

    private func isActiveTurn(_ id: UUID) -> Bool {
        activeTurn?.id == id
    }

    private func completeActiveTurn() {
        guard var turn = activeTurn else { return }
        turn.status = .complete
        activeTurn = turn
    }

    private func failActiveTurn() {
        guard var turn = activeTurn else { return }
        turn.status = .failed
        activeTurn = turn
    }

    private func cancelActiveTurn() {
        guard var turn = activeTurn else { return }
        turn.status = .cancelled
        activeTurn = turn
    }

    private func appendTurnWarning(_ warning: String) {
        guard !warning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        turnWarnings.append(warning)
        if turnWarnings.count > 12 {
            turnWarnings.removeFirst(turnWarnings.count - 12)
        }
    }
}
