import Carbon
import Foundation

public final class GlobalHotkeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID: UInt32

    nonisolated(unsafe) private static var nextID: UInt32 = 1
    nonisolated(unsafe) private static var handlers: [UInt32: @MainActor () -> Void] = [:]
    nonisolated(unsafe) private static var eventHandlerInstalled = false

    public init() {
        hotKeyID = Self.nextID
        Self.nextID += 1
    }

    deinit {
        unregister()
    }

    public func registerOptionSpace(handler: @escaping @MainActor () -> Void) {
        unregister()
        installEventHandlerIfNeeded()
        Self.handlers[hotKeyID] = handler

        var id = EventHotKeyID(signature: OSType(0x4a525653), id: hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            id,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            Self.handlers.removeValue(forKey: hotKeyID)
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        Self.handlers.removeValue(forKey: hotKeyID)
    }

    private func installEventHandlerIfNeeded() {
        guard !Self.eventHandlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            guard status == noErr else { return noErr }
            if let handler = GlobalHotkeyManager.handlers[id.id] {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        handler()
                    }
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
        Self.eventHandlerInstalled = true
    }
}
