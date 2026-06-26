import AVFoundation
import Foundation
import Speech

@MainActor
public final class SpeechTranscriberManager: NSObject {
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onError: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var latestTranscript = ""
    private var lastVoiceActivityAt = Date.distantPast
    private var lastVoiceActivityEmitAt = Date.distantPast
    private var permissionRequestTask: Task<Bool, Never>?
    private let voiceActivityReleaseInterval: TimeInterval = 0.35
    private nonisolated static let voiceActivityLevelThreshold: Float = 0.012

    public var isListening: Bool {
        audioEngine.isRunning
    }

    public var isVoiceActive: Bool {
        Date().timeIntervalSince(lastVoiceActivityAt) < voiceActivityReleaseInterval
    }

    public func requestPermissions() async -> Bool {
        if let permissionRequestTask {
            return await permissionRequestTask.value
        }

        let task = Task { await Self.resolvePermissions() }
        permissionRequestTask = task
        let allowed = await task.value
        permissionRequestTask = nil
        return allowed
    }

    private nonisolated static func resolvePermissions() async -> Bool {
        let speechStatus = await speechAuthorizationStatus()
        let micAllowed = await microphoneAccessAllowed()
        return speechStatus == .authorized && micAllowed
    }

    private nonisolated static func speechAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated static func microphoneAccessAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await requestMicrophoneAccess()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private nonisolated static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    public func start() throws {
        stop()
        latestTranscript = ""
        lastVoiceActivityAt = .distantPast
        lastVoiceActivityEmitAt = .distantPast

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 10.15, *) {
            request.requiresOnDeviceRecognition = false
        }
        recognitionRequest = request

        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "JarvisSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is unavailable."])
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        Self.installTap(on: inputNode, format: format, request: request, manager: self)

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = Self.startRecognitionTask(recognizer: recognizer, request: request, manager: self)
    }

    private nonisolated static func installTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest,
        manager: SpeechTranscriberManager
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak manager] buffer, _ in
            request.append(buffer)
            guard Self.hasVoiceActivity(in: buffer, threshold: Self.voiceActivityLevelThreshold) else {
                return
            }
            Task { @MainActor [weak manager] in
                manager?.handleVoiceActivity()
            }
        }
    }

    private nonisolated static func hasVoiceActivity(in buffer: AVAudioPCMBuffer, threshold: Float) -> Bool {
        guard let channels = buffer.floatChannelData else { return false }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return false }

        var sum: Float = 0
        let channelCount = max(1, Int(buffer.format.channelCount))
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frame in 0..<frameLength {
                let sample = channel[frame]
                sum += sample * sample
            }
        }
        let rms = sqrt(sum / Float(frameLength * channelCount))
        return rms >= threshold
    }

    private nonisolated static func startRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        manager: SpeechTranscriberManager
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak manager] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorMessage = error?.localizedDescription
            Task { @MainActor [weak manager] in
                manager?.handleRecognition(text: text, isFinal: isFinal, errorMessage: errorMessage)
            }
        }
    }

    private func handleRecognition(text: String?, isFinal: Bool, errorMessage: String?) {
        if let text {
            latestTranscript = text
            if isFinal {
                onFinalTranscript?(text)
            } else {
                onPartialTranscript?(text)
            }
        }
        if let errorMessage {
            onError?(errorMessage)
            stop()
        }
    }

    private func handleVoiceActivity() {
        let now = Date()
        lastVoiceActivityAt = now
        guard now.timeIntervalSince(lastVoiceActivityEmitAt) >= 0.15 else {
            return
        }
        lastVoiceActivityEmitAt = now
        onVoiceActivity?()
    }

    @discardableResult
    public func stop() -> String {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        let transcript = latestTranscript
        latestTranscript = ""
        return transcript
    }
}
