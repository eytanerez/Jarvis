import AVFoundation
import Foundation
import JarvisCore

@MainActor
public final class TTSManager: NSObject, @preconcurrency AVAudioPlayerDelegate, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentGenerationId: UUID?
    private var audioPlayer: AVAudioPlayer?
    private var audioFileURL: URL?
    private var speechTask: Task<Void, Never>?
    private weak var brainClient: BrainClient?
    private var settings = VoiceSettings()
    private var stoppedIntentionally = false
    private var playbackStarted = false
    private var localTTSSuppressedUntil: Date?
    private let localTTSCooldownSeconds: TimeInterval = 300
    public var voiceIdentifier: String?
    public var onPreparing: (() -> Void)?
    public var onPlaybackStarted: (() -> Void)?
    public var onPlaybackFinished: (() -> Void)?
    public var onPlaybackFailed: ((String) -> Void)?
    public var onDebug: ((String) -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func configure(settings: VoiceSettings, brainClient: BrainClient?) {
        self.settings = settings
        self.brainClient = brainClient
        voiceIdentifier = settings.voiceIdentifier
    }

    public func speak(_ text: String, limit: Int = 220, style: VoiceStyle? = nil) {
        stop(notify: false)
        stoppedIntentionally = false
        playbackStarted = false
        let generationId = UUID()
        currentGenerationId = generationId
        let clipped = text.count > limit ? String(text.prefix(limit)) : text
        guard !clipped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentGenerationId = nil
            return
        }
        onPreparing?()
        log("request \(generationId.uuidString) textLength=\(clipped.count) first80=\"\(String(clipped.prefix(80)))\"")
        let voiceStyle = style ?? VoiceStyle.style(for: .neutral, spokenLimit: limit)
        if settings.ttsEngine == .kokoro || settings.ttsEngine == .chatterbox, let brainClient {
            if localTTSIsSuppressed {
                log("local TTS cooldown active; using Apple speech")
                speakWithApple(clipped, generationId: generationId, allowFallback: true, fallbackUsed: true, style: voiceStyle)
                return
            }
            let primaryRequest = synthesisRequest(
                text: clipped,
                engine: settings.ttsEngine,
                settings: settings,
                style: voiceStyle
            )
            let kokoroFallbackRequest = TTSSynthesisRequest(
                text: clipped,
                engine: TTSEngine.kokoro.rawValue,
                voice: settings.kokoroVoice,
                speed: scaledSpeed(settings.kokoroSpeed, style: voiceStyle)
            )
            speechTask = Task { [weak self, brainClient, settings, generationId, clipped, primaryRequest, kokoroFallbackRequest] in
                guard await brainClient.health() else {
                    await MainActor.run {
                        self?.noteLocalTTSUnavailable("Local TTS server is not reachable.")
                        self?.speakWithApple(
                            clipped,
                            generationId: generationId,
                            allowFallback: settings.fallbackToAppleSpeech,
                            fallbackUsed: true,
                            style: voiceStyle
                        )
                    }
                    return
                }

                do {
                    let data = try await brainClient.synthesizeSpeech(primaryRequest)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.handleAudioResponse(
                            data: data,
                            generationId: generationId,
                            fallbackText: clipped,
                            allowFallback: settings.fallbackToAppleSpeech
                        )
                    }
                } catch {
                    if settings.ttsEngine == .chatterbox, settings.fallbackToAppleSpeech {
                        do {
                            let data = try await brainClient.synthesizeSpeech(kokoroFallbackRequest)
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                self?.handleAudioResponse(
                                    data: data,
                                    generationId: generationId,
                                    fallbackText: clipped,
                                    allowFallback: settings.fallbackToAppleSpeech
                                )
                            }
                            return
                        } catch {
                            await MainActor.run {
                                self?.handlePlaybackFailure(
                                    message: "Chatterbox and Kokoro could not synthesize speech: \(error.localizedDescription)",
                                    generationId: generationId,
                                    fallbackText: clipped,
                                    allowFallback: settings.fallbackToAppleSpeech
                                )
                            }
                            return
                        }
                    }
                    await MainActor.run {
                        self?.handlePlaybackFailure(
                            message: "\(settings.ttsEngine.displayName) could not synthesize speech: \(error.localizedDescription)",
                            generationId: generationId,
                            fallbackText: clipped,
                            allowFallback: settings.fallbackToAppleSpeech
                        )
                    }
                }
            }
            return
        }
        speakWithApple(clipped, generationId: generationId, allowFallback: true, fallbackUsed: false, style: voiceStyle)
    }

    private func synthesisRequest(text: String, engine: TTSEngine, settings: VoiceSettings, style: VoiceStyle) -> TTSSynthesisRequest {
        let referencePath = settings.chatterboxVoiceReferencePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return TTSSynthesisRequest(
            text: text,
            engine: engine.rawValue,
            voice: style.ttsVoice ?? settings.kokoroVoice,
            speed: scaledSpeed(settings.kokoroSpeed, style: style),
            referenceAudioPath: referencePath.isEmpty ? nil : referencePath,
            exaggeration: scaled(settings.chatterboxExaggeration, target: style.exaggeration, minimum: 0.15, maximum: 1.20),
            cfgWeight: scaled(settings.chatterboxCfgWeight, target: style.cfgWeight, minimum: 0.10, maximum: 1.20),
            stylePreset: settings.chatterboxStylePreset
        )
    }

    private func scaledSpeed(_ speed: Double, style: VoiceStyle) -> Double {
        scaled(speed, target: style.speed, minimum: 0.5, maximum: 1.8)
    }

    private func scaled(_ base: Double, target: Double, minimum: Double, maximum: Double) -> Double {
        min(max(base * target, minimum), maximum)
    }

    private func handleAudioResponse(data: Data, generationId: UUID, fallbackText: String, allowFallback: Bool) {
        guard currentGenerationId == generationId else {
            log("stale response ignored \(generationId.uuidString) bytes=\(data.count)")
            return
        }
        localTTSSuppressedUntil = nil
        log("response \(generationId.uuidString) bytes=\(data.count)")

        do {
            cleanupAudioFile()
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("JarvisTTS-\(generationId.uuidString)")
                .appendingPathExtension("wav")
            try data.write(to: fileURL, options: .atomic)
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            player.currentTime = 0
            player.volume = 1.0
            audioPlayer = player
            audioFileURL = fileURL
            player.prepareToPlay()
            let startTime = player.deviceCurrentTime + 0.18
            guard player.play(atTime: startTime) else {
                throw NSError(domain: "JarvisTTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "The local voice player did not start."])
            }
            playbackStarted = true
            log("player started \(generationId.uuidString) duration=\(String(format: "%.2f", player.duration))")
            onPlaybackStarted?()
        } catch {
            handlePlaybackFailure(
                message: "Kokoro audio could not play: \(error.localizedDescription)",
                generationId: generationId,
                fallbackText: fallbackText,
                allowFallback: allowFallback
            )
        }
    }

    private func speakWithApple(_ text: String, generationId: UUID, allowFallback: Bool, fallbackUsed: Bool, style: VoiceStyle? = nil) {
        guard currentGenerationId == generationId else {
            log("stale Apple speech ignored \(generationId.uuidString)")
            return
        }
        guard allowFallback else {
            currentGenerationId = nil
            onPlaybackFinished?()
            return
        }
        log("Apple speech started \(generationId.uuidString) fallbackUsed=\(fallbackUsed)")
        let utterance = AVSpeechUtterance(string: text)
        if let voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        let speed = Float(style?.speed ?? 1.0)
        utterance.rate = min(max(AVSpeechUtteranceDefaultSpeechRate * speed, 0.35), 0.62)
        utterance.preUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    public func stop() {
        stop(notify: false)
    }

    private func stop(notify: Bool) {
        stoppedIntentionally = true
        speechTask?.cancel()
        speechTask = nil
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        cleanupAudioFile()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let generationId = currentGenerationId {
            log("stopped \(generationId.uuidString)")
        }
        currentGenerationId = nil
        playbackStarted = false
        if notify {
            onPlaybackFinished?()
        }
    }

    public var isSpeaking: Bool {
        synthesizer.isSpeaking || (audioPlayer?.isPlaying == true)
    }

    private func handlePlaybackFailure(message: String, generationId: UUID, fallbackText: String?, allowFallback: Bool) {
        guard currentGenerationId == generationId else {
            log("stale failure ignored \(generationId.uuidString): \(message)")
            return
        }
        log("failure \(generationId.uuidString): \(message)")
        if let fallbackText, allowFallback, !playbackStarted {
            noteLocalTTSUnavailable(message)
            speakWithApple(fallbackText, generationId: generationId, allowFallback: true, fallbackUsed: true)
        } else {
            onPlaybackFailed?(message)
            currentGenerationId = nil
            onPlaybackFinished?()
        }
    }

    private var localTTSIsSuppressed: Bool {
        guard let until = localTTSSuppressedUntil else { return false }
        if Date() < until {
            return true
        }
        localTTSSuppressedUntil = nil
        return false
    }

    private func noteLocalTTSUnavailable(_ message: String) {
        localTTSSuppressedUntil = Date().addingTimeInterval(localTTSCooldownSeconds)
        log("local TTS unavailable; using Apple fallback for \(Int(localTTSCooldownSeconds))s: \(message)")
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === audioPlayer else { return }
        if let generationId = currentGenerationId {
            log("player completed \(generationId.uuidString) success=\(flag)")
        }
        audioPlayer = nil
        cleanupAudioFile()
        currentGenerationId = nil
        playbackStarted = false
        if !stoppedIntentionally {
            onPlaybackFinished?()
        }
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        guard player === audioPlayer else { return }
        if let generationId = currentGenerationId {
            log("player interrupted \(generationId.uuidString): \(error?.localizedDescription ?? "decode error")")
        }
        audioPlayer = nil
        cleanupAudioFile()
        currentGenerationId = nil
        playbackStarted = false
        guard !stoppedIntentionally else { return }
        onPlaybackFailed?(error?.localizedDescription ?? "The local voice player hit a decode error.")
        onPlaybackFinished?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        playbackStarted = true
        onPlaybackStarted?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentGenerationId = nil
        playbackStarted = false
        if !stoppedIntentionally {
            onPlaybackFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentGenerationId = nil
        playbackStarted = false
        if !stoppedIntentionally {
            onPlaybackFinished?()
        }
    }

    private func cleanupAudioFile() {
        if let audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
        }
        audioFileURL = nil
    }

    private func log(_ message: String) {
        let line = "[JarvisTTS] \(message)"
        print(line)
        onDebug?(message)
    }
}
