import Foundation

public struct SystemAudioController: Sendable {
    private let scripts = AppleScriptRunner()

    public init() {}

    public func volumeUp() -> String {
        _ = scripts.run("set currentVolume to output volume of (get volume settings)\nset volume output volume (currentVolume + 10)")
        return "Volume up."
    }

    public func volumeDown() -> String {
        _ = scripts.run("set currentVolume to output volume of (get volume settings)\nset volume output volume (currentVolume - 10)")
        return "Volume down."
    }

    public func mute() -> String {
        _ = scripts.run("set volume output muted true")
        return "Muted."
    }
}
