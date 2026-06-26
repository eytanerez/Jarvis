import Foundation

public struct SpotifyController: Sendable {
    private let scripts = AppleScriptRunner()

    public init() {}

    public func play() -> String {
        _ = scripts.run(#"tell application "Spotify" to play"#)
        return "Playing."
    }

    public func pause() -> String {
        _ = scripts.run(#"tell application "Spotify" to pause"#)
        return "Paused."
    }

    public func next() -> String {
        _ = scripts.run(#"tell application "Spotify" to next track"#)
        return "Skipping."
    }

    public func previous() -> String {
        _ = scripts.run(#"tell application "Spotify" to previous track"#)
        return "Going back."
    }

    public func currentTrack() -> String {
        let script = #"""
        tell application "Spotify"
          if it is running then
            if player state is stopped then return "Spotify is stopped."
            set trackName to name of current track
            set artistName to artist of current track
            return trackName & " by " & artistName
          else
            return "Spotify is not open."
          end if
        end tell
        """#
        return scripts.run(script) ?? "I couldn't read Spotify right now."
    }
}
