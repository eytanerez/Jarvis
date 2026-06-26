import AppKit
import Foundation

public enum PushToTalkTrigger: String, CaseIterable, Codable, Sendable {
    case function
    case rightOption

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .function:
            .function
        case .rightOption:
            .option
        }
    }
}

@MainActor
public final class PushToTalkHotkey {
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var trigger: PushToTalkTrigger = .function
    private var isPressed = false
    private var lastReleaseAt = Date.distantPast
    private let doubleTapInterval: TimeInterval = 0.35

    public init() {}

    deinit {
        MainActor.assumeIsolated {
            unregister()
        }
    }

    public func register(
        trigger: PushToTalkTrigger,
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void,
        onDoubleTap: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        unregister()
        self.trigger = trigger

        let flagsHandler: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlags(event, onPress: onPress, onRelease: onRelease, onDoubleTap: onDoubleTap)
            }
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flagsHandler)
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            flagsHandler(event)
            return event
        }

        let keyHandler: (NSEvent) -> Void = { event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in onCancel() }
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyHandler)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                keyHandler(event)
            }
            return event
        }
    }

    public func unregister() {
        for monitor in [globalFlagsMonitor, localFlagsMonitor, globalKeyMonitor, localKeyMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyMonitor = nil
        localKeyMonitor = nil
        isPressed = false
    }

    private func handleFlags(
        _ event: NSEvent,
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void,
        onDoubleTap: @escaping @MainActor () -> Void
    ) {
        let pressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(trigger.modifierFlag)
        if pressed, !isPressed {
            isPressed = true
            if Date().timeIntervalSince(lastReleaseAt) <= doubleTapInterval {
                onDoubleTap()
            } else {
                onPress()
            }
        } else if !pressed, isPressed {
            isPressed = false
            lastReleaseAt = Date()
            onRelease()
        }
    }
}
