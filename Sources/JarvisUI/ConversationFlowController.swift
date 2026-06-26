import Foundation

/// Owns the speech end-of-turn timing state machine that used to live inline in
/// `JarvisAppModel`: the auto-submit and follow-up-timeout timers, the activity
/// timestamps they compare against, and the `isSubmitting` / `awaitingFollowUp`
/// flags that gate them.
///
/// `JarvisAppModel` keeps the orchestration (routing, TTS, phase/UI); it drives
/// this controller through a few intent-revealing methods and receives the two
/// timer outcomes through `onAutoSubmit` / `onFollowUpTimeout`. Pulling this out
/// shrinks the model by ~150 lines and isolates the trickiest concurrency in one
/// place that can be reasoned about (and tested) on its own.
@MainActor
final class ConversationFlowController {
    /// Quiet time after speech before we auto-submit the first utterance.
    private let initialEndOfSpeechSeconds = 1.2
    /// Longer pause tolerated when listening for a follow-up reply.
    private let followUpEndOfSpeechSeconds = 1.4
    /// How long to wait for the user to start a follow-up before we bow out.
    private let followUpStartGraceSeconds = 2.0

    /// True once a transcript has been handed off for processing. Blocks any
    /// further timer-driven submission for the current utterance.
    private(set) var isSubmitting = false
    /// True while listening specifically for a follow-up reply.
    private(set) var awaitingFollowUp = false

    private var listeningStartedAt = Date.distantPast
    private var lastVoiceActivityAt = Date.distantPast
    private var lastTranscriptActivityAt = Date.distantPast
    private var autoSubmitTask: Task<Void, Never>?
    private var followUpNoSpeechTask: Task<Void, Never>?

    // Injected collaborators — kept as closures so the controller has no
    // dependency on the speech engine or the app model.
    var isVoiceActive: @MainActor () -> Bool = { false }
    /// Returns the current transcript, already whitespace-trimmed.
    var currentTranscript: @MainActor () -> String = { "" }
    var onAutoSubmit: @MainActor () -> Void = {}
    var onFollowUpTimeout: @MainActor () -> Void = {}

    /// Reset all timing state at the start of a listening session.
    func beginListening(followUp: Bool) {
        cancelTimers()
        isSubmitting = false
        awaitingFollowUp = followUp
        listeningStartedAt = Date()
        lastVoiceActivityAt = .distantPast
        lastTranscriptActivityAt = .distantPast
    }

    /// Arm the "user never spoke a follow-up" timeout. Call after the speech
    /// recognizer has started for a follow-up turn.
    func armFollowUpTimeout() {
        scheduleFollowUpNoSpeechTimeout()
    }

    func noteTranscriptActivity() {
        lastTranscriptActivityAt = Date()
    }

    func noteVoiceActivity() {
        guard !isSubmitting else { return }
        lastVoiceActivityAt = Date()
        if !currentTranscript().isEmpty {
            scheduleAutoSubmit()
        }
    }

    func cancelFollowUpTimeout() {
        followUpNoSpeechTask?.cancel()
    }

    /// Mark the turn as handed off for processing; no further auto-submission.
    func markSubmitted() {
        isSubmitting = true
        cancelTimers()
    }

    func clearAwaitingFollowUp() {
        awaitingFollowUp = false
    }

    func cancelTimers() {
        autoSubmitTask?.cancel()
        followUpNoSpeechTask?.cancel()
    }

    /// Schedule (or reschedule) an auto-submit once the user has been quiet for
    /// the natural-pause window.
    func scheduleAutoSubmit() {
        autoSubmitTask?.cancel()
        let naturalPauseDelay = awaitingFollowUp ? followUpEndOfSpeechSeconds : initialEndOfSpeechSeconds
        autoSubmitTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(naturalPauseDelay * 1000)))
            await MainActor.run {
                guard let self else { return }
                guard !self.isSubmitting else { return }
                guard !self.currentTranscript().isEmpty else { return }
                let lastActivity = max(self.lastVoiceActivityAt, self.lastTranscriptActivityAt)
                let quietFor = Date().timeIntervalSince(lastActivity)
                guard quietFor >= naturalPauseDelay, !self.isVoiceActive() else {
                    self.scheduleAutoSubmit()
                    return
                }
                self.onAutoSubmit()
            }
        }
    }

    private func scheduleFollowUpNoSpeechTimeout() {
        followUpNoSpeechTask?.cancel()
        let delay = followUpStartGraceSeconds
        followUpNoSpeechTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            await MainActor.run {
                guard let self else { return }
                guard self.awaitingFollowUp, !self.isSubmitting else { return }
                guard self.currentTranscript().isEmpty else { return }
                if self.lastVoiceActivityAt > self.listeningStartedAt {
                    self.scheduleFollowUpNoSpeechTimeout()
                    return
                }
                self.onFollowUpTimeout()
            }
        }
    }
}
