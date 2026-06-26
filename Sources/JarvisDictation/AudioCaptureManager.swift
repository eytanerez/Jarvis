import Foundation
import JarvisMac

@MainActor
public final class AudioCaptureManager {
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onError: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    private let speech = SpeechTranscriberManager()

    public init() {
        speech.onPartialTranscript = { [weak self] text in
            self?.onPartialTranscript?(text)
        }
        speech.onFinalTranscript = { [weak self] text in
            self?.onFinalTranscript?(text)
        }
        speech.onError = { [weak self] message in
            self?.onError?(message)
        }
        speech.onVoiceActivity = { [weak self] in
            self?.onVoiceActivity?()
        }
    }

    public var isRecording: Bool {
        speech.isListening
    }

    public func requestPermissions() async -> Bool {
        await speech.requestPermissions()
    }

    public func start() throws {
        try speech.start()
    }

    @discardableResult
    public func stop() -> String {
        speech.stop()
    }
}
