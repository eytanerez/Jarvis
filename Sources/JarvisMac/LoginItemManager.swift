import Foundation
import ServiceManagement

/// Launch-at-login control, mirroring how always-on utilities like AltTab start
/// themselves with the system. Backed by `SMAppService.mainApp`, which registers
/// the app bundle itself as a login item (macOS 13+).
@MainActor
public struct LoginItemManager {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register the app to open at login. Safe to call repeatedly. No-ops when
    /// already enabled or when run from a non-bundled binary (e.g. `swift run`).
    @discardableResult
    public func enable() -> Bool {
        guard SMAppService.mainApp.status != .enabled else { return true }
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            print("[JarvisNotch] Could not register login item: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            print("[JarvisNotch] Could not unregister login item: \(error.localizedDescription)")
            return false
        }
    }

    public func setEnabled(_ enabled: Bool) {
        enabled ? enable() : disable()
    }

    /// Register once on first run so a freshly installed app starts at login
    /// without the user hunting for a toggle — but never fight a user who has
    /// since turned it off.
    public func enableOnFirstRunIfNeeded() {
        let key = "JarvisNotch.didRegisterLoginItemOnce"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        enable()
    }
}
