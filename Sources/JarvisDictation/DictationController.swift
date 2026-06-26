import Foundation
import JarvisMac

public enum DictationPhase: String, Codable, Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case formatting
    case inserting
    case inserted
    case canceled
    case error
}

public struct DictationStatus: Codable, Equatable, Sendable {
    public var phase: DictationPhase
    public var transcript: String
    public var cleanedText: String
    public var insertedText: String
    public var activeAppName: String?
    public var message: String
    public var handsFreeActive: Bool
    public var updatedAt: Date

    public static let idle = DictationStatus(
        phase: .idle,
        transcript: "",
        cleanedText: "",
        insertedText: "",
        activeAppName: nil,
        message: "Dictation ready",
        handsFreeActive: false,
        updatedAt: Date()
    )
}

public struct DictationConfiguration: Equatable, Sendable {
    public var hotkey: String
    public var handsFreeEnabled: Bool
    public var sttEngine: String
    public var postProcessing: String
    public var insertAutomatically: Bool
    public var playSoundFeedback: Bool

    public init(
        hotkey: String = "function",
        handsFreeEnabled: Bool = true,
        sttEngine: String = "apple",
        postProcessing: String = "off",
        insertAutomatically: Bool = true,
        playSoundFeedback: Bool = true
    ) {
        self.hotkey = hotkey
        self.handsFreeEnabled = handsFreeEnabled
        self.sttEngine = sttEngine
        self.postProcessing = postProcessing
        self.insertAutomatically = insertAutomatically
        self.playSoundFeedback = playSoundFeedback
    }
}

@MainActor
public final class DictationController {
    public var onStatusChanged: ((DictationStatus) -> Void)?
    public var onWillStartRecording: (() -> Void)?

    private let audio = AudioCaptureManager()
    private let insertion = TextInsertionManager()
    private let hotkey = PushToTalkHotkey()
    private var brainClient: BrainClient?
    private var activeAppNameProvider: (() -> String?)?
    private var configuration = DictationConfiguration()
    private var latestTranscript = ""
    private var activeAppName: String?
    private var finishingTask: Task<Void, Never>?

    public private(set) var status: DictationStatus = .idle {
        didSet { onStatusChanged?(status) }
    }

    public init() {
        audio.onPartialTranscript = { [weak self] text in
            self?.latestTranscript = text
            self?.setStatus(.transcribing, transcript: text, message: "Transcribing…")
        }
        audio.onFinalTranscript = { [weak self] text in
            self?.latestTranscript = text
            self?.setStatus(.transcribing, transcript: text, message: "Transcribing…")
        }
        audio.onError = { [weak self] message in
            self?.setStatus(.error, message: message)
        }
    }

    public func configure(
        _ configuration: DictationConfiguration,
        brainClient: BrainClient,
        activeAppNameProvider: @escaping () -> String?
    ) {
        self.configuration = configuration
        self.brainClient = brainClient
        self.activeAppNameProvider = activeAppNameProvider
        hotkey.register(
            trigger: PushToTalkTrigger(rawValue: configuration.hotkey) ?? .function,
            onPress: { [weak self] in
                self?.startHoldDictation()
            },
            onRelease: { [weak self] in
                self?.finishHoldDictation()
            },
            onDoubleTap: { [weak self] in
                self?.toggleHandsFreeDictation()
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
    }

    public func unregister() {
        hotkey.unregister()
        finishingTask?.cancel()
        if audio.isRecording {
            _ = audio.stop()
        }
        status = .idle
    }

    public func startHoldDictation() {
        guard !status.handsFreeActive else { return }
        startRecording(handsFree: false)
    }

    public func finishHoldDictation() {
        guard !status.handsFreeActive else { return }
        finishRecording()
    }

    public func toggleHandsFreeDictation() {
        guard configuration.handsFreeEnabled else { return }
        if status.handsFreeActive || audio.isRecording {
            finishRecording()
        } else {
            startRecording(handsFree: true)
        }
    }

    public func cancel() {
        finishingTask?.cancel()
        if audio.isRecording {
            _ = audio.stop()
        }
        latestTranscript = ""
        setStatus(.canceled, message: "Dictation canceled")
    }

    private func startRecording(handsFree: Bool) {
        guard !audio.isRecording else { return }
        finishingTask?.cancel()
        onWillStartRecording?()
        latestTranscript = ""
        activeAppName = activeAppNameProvider?()
        Task {
            guard await audio.requestPermissions() else {
                setStatus(.error, message: "Dictation needs microphone and speech recognition access.")
                return
            }
            do {
                try audio.start()
                setStatus(
                    .recording,
                    activeAppName: activeAppName,
                    message: handsFree ? "Hands-free dictation…" : "Dictating…",
                    handsFreeActive: handsFree
                )
            } catch {
                setStatus(.error, activeAppName: activeAppName, message: error.localizedDescription)
            }
        }
    }

    private func finishRecording() {
        guard audio.isRecording else { return }
        let transcript = audio.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        latestTranscript = transcript.isEmpty ? latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines) : transcript
        let finalTranscript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalTranscript.isEmpty else {
            setStatus(.idle, activeAppName: activeAppName, message: "No dictation captured")
            return
        }
        finishingTask?.cancel()
        finishingTask = Task { [weak self] in
            guard let self else { return }
            await self.cleanFormatAndInsert(finalTranscript)
        }
    }

    private func cleanFormatAndInsert(_ transcript: String) async {
        setStatus(.formatting, transcript: transcript, activeAppName: activeAppName, message: "Cleaning dictation…")
        let cleaned = await clean(transcript)
        let formatted = await format(cleaned, activeAppName: activeAppName)
        guard configuration.insertAutomatically else {
            setStatus(.inserted, transcript: transcript, cleanedText: cleaned, insertedText: formatted, activeAppName: activeAppName, message: "Dictation ready")
            return
        }
        setStatus(.inserting, transcript: transcript, cleanedText: cleaned, insertedText: formatted, activeAppName: activeAppName, message: "Inserting…")
        let inserted = await insertion.insert(formatted)
        setStatus(
            inserted ? .inserted : .error,
            transcript: transcript,
            cleanedText: cleaned,
            insertedText: inserted ? formatted : "",
            activeAppName: activeAppName,
            message: inserted ? "Dictation inserted" : "Could not insert dictation"
        )
    }

    private func clean(_ text: String) async -> String {
        guard let brainClient else { return fallbackClean(text) }
        do {
            return try await brainClient.cleanDictation(text)
        } catch {
            return fallbackClean(text)
        }
    }

    private func format(_ text: String, activeAppName: String?) async -> String {
        guard let brainClient else { return text }
        do {
            return try await brainClient.formatDictation(text, activeApp: activeAppName)
        } catch {
            return text
        }
    }

    private func fallbackClean(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"(?i)\b(um+|uh+|erm)\b[, ]*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setStatus(
        _ phase: DictationPhase,
        transcript: String? = nil,
        cleanedText: String? = nil,
        insertedText: String? = nil,
        activeAppName: String? = nil,
        message: String,
        handsFreeActive: Bool? = nil
    ) {
        status = DictationStatus(
            phase: phase,
            transcript: transcript ?? latestTranscript,
            cleanedText: cleanedText ?? status.cleanedText,
            insertedText: insertedText ?? status.insertedText,
            activeAppName: activeAppName ?? status.activeAppName,
            message: message,
            handsFreeActive: handsFreeActive ?? (phase == .idle || phase == .inserted || phase == .canceled || phase == .error ? false : status.handsFreeActive),
            updatedAt: Date()
        )
    }
}
