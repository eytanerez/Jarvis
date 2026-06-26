/*
 * Jarvis integration for the Atoll notch shell.
 *
 * Atoll owns presentation, windows, tabs, hover behavior, gestures, and settings.
 * Jarvis owns assistant intelligence, speech, TTS, context, memory, and actions.
 */

import Combine
import Foundation
import JarvisCore
import JarvisMac
import JarvisUI

@MainActor
final class JarvisAssistantBridge: ObservableObject {
    static let shared = JarvisAssistantBridge()

    let model = JarvisAppModel.shared

    private let hotkey = GlobalHotkeyManager()
    private var activationHandler: (@MainActor () -> Void)?
    private var deactivationHandler: (@MainActor () -> Void)?
    private var phaseCancellable: AnyCancellable?
    private var conversationWasActive = false
    private var musicPausedForConversation = false
    private var shouldResumeMusicWhenIdle = false
    private var started = false

    private init() {}

    func start(
        activate: @escaping @MainActor () -> Void,
        deactivate: @escaping @MainActor () -> Void
    ) {
        activationHandler = activate
        deactivationHandler = deactivate
        guard !started else { return }
        started = true
        JarvisScheduleSnapshotProvider.shared.start()
        model.scheduleContextProvider = {
            JarvisScheduleSnapshotProvider.shared.snapshot()
        }
        model.onLocalActionWillExecute = { [weak self] action in
            self?.handleLocalAction(action)
        }
        phaseCancellable = model.$phase.sink { [weak self] phase in
            self?.handlePhaseChange(phase)
        }
        model.startEmbedded()
        hotkey.registerOptionSpace { [weak self] in
            self?.activationHandler?()
        }
    }

    func stop() {
        hotkey.unregister()
        phaseCancellable?.cancel()
        phaseCancellable = nil
        resumeMusicIfNeeded()
        model.shutdown()
        model.scheduleContextProvider = nil
        model.onLocalActionWillExecute = nil
        activationHandler = nil
        deactivationHandler = nil
        conversationWasActive = false
        started = false
    }

    func activateConversation() {
        model.toggleFromHotkey()
    }

    private func handlePhaseChange(_ phase: AssistantPhase) {
        if isConversationActive(phase) {
            conversationWasActive = true
            pauseMusicIfNeeded()
            return
        }

        resumeMusicIfNeeded()

        if case .idle = phase, conversationWasActive {
            conversationWasActive = false
            deactivationHandler?()
        }

        if case .error = phase {
            conversationWasActive = false
        }
    }

    private func isConversationActive(_ phase: AssistantPhase) -> Bool {
        switch phase {
        case .listening, .transcribing, .thinking, .acting, .speaking, .results, .confirming:
            return true
        case .idle, .error:
            return false
        }
    }

    private func pauseMusicIfNeeded() {
        guard !musicPausedForConversation, MusicManager.shared.isPlaying else { return }
        MusicManager.shared.pause()
        musicPausedForConversation = true
        shouldResumeMusicWhenIdle = true
    }

    private func resumeMusicIfNeeded() {
        guard musicPausedForConversation else {
            shouldResumeMusicWhenIdle = false
            return
        }
        if shouldResumeMusicWhenIdle, !MusicManager.shared.isPlaying {
            MusicManager.shared.play()
        }
        musicPausedForConversation = false
        shouldResumeMusicWhenIdle = false
    }

    private func handleLocalAction(_ action: AssistantAction) {
        switch action.type {
        case "spotify_pause":
            shouldResumeMusicWhenIdle = false
        case "spotify_play":
            musicPausedForConversation = false
            shouldResumeMusicWhenIdle = false
        default:
            break
        }
    }
}
