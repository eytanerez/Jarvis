/*
 * Jarvis integration for the Atoll notch shell.
 *
 * Atoll owns presentation, windows, tabs, hover behavior, gestures, and settings.
 * Jarvis owns assistant intelligence, speech, TTS, context, memory, and actions.
 */

import Foundation
import JarvisMac
import JarvisUI

@MainActor
final class JarvisAssistantBridge: ObservableObject {
    static let shared = JarvisAssistantBridge()

    let model = JarvisAppModel.shared

    private let hotkey = GlobalHotkeyManager()
    private var activationHandler: (@MainActor () -> Void)?
    private var started = false

    private init() {}

    func start(activate: @escaping @MainActor () -> Void) {
        activationHandler = activate
        guard !started else { return }
        started = true
        JarvisScheduleSnapshotProvider.shared.start()
        model.scheduleContextProvider = {
            JarvisScheduleSnapshotProvider.shared.snapshot()
        }
        model.startEmbedded()
        hotkey.registerOptionSpace { [weak self] in
            self?.activationHandler?()
        }
    }

    func stop() {
        hotkey.unregister()
        model.shutdown()
        model.scheduleContextProvider = nil
        activationHandler = nil
        started = false
    }

    func activateConversation() {
        model.toggleFromHotkey()
    }
}
