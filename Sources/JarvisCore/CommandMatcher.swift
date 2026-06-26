import Foundation

public enum CommandMatch: Equatable, Sendable {
    case handled(response: String?, action: AssistantAction?)
    case needsConfirmation(ConfirmationRequest)
    case notMatched
}

public struct CommandMatcher: Sendable {
    public init() {}

    public func match(_ transcript: String, shortcuts: [ShortcutConfig] = []) -> CommandMatch {
        let text = normalize(transcript)

        if ["cancel", "stop", "stop listening"].contains(text) {
            return .handled(response: "Canceled.", action: AssistantAction(type: "cancel"))
        }

        if ["stop talking", "be quiet", "quiet"].contains(text) {
            return .handled(response: nil, action: AssistantAction(type: "stop_tts"))
        }

        if ["pause", "pause this", "stop music", "play pause"].contains(text) {
            return .handled(response: "Paused.", action: AssistantAction(type: "spotify_pause"))
        }

        if ["play", "resume", "resume music"].contains(text) {
            return .handled(response: "Playing.", action: AssistantAction(type: "spotify_play"))
        }

        if ["skip", "next", "next song", "skip this"].contains(text) {
            return .handled(response: "Skipping.", action: AssistantAction(type: "spotify_next"))
        }

        if ["previous", "go back", "previous song"].contains(text) {
            return .handled(response: "Going back.", action: AssistantAction(type: "spotify_previous"))
        }

        if ["what song is this", "what's playing", "what is playing"].contains(text) {
            return .handled(response: nil, action: AssistantAction(type: "spotify_current_track"))
        }

        if text == "volume up" || text == "turn it up" {
            return .handled(response: "Volume up.", action: AssistantAction(type: "system_volume_up"))
        }

        if text == "volume down" || text == "turn it down" {
            return .handled(response: "Volume down.", action: AssistantAction(type: "system_volume_down"))
        }

        if text == "mute" || text == "mute volume" {
            return .handled(response: "Muted.", action: AssistantAction(type: "system_mute"))
        }

        if let shellCommand = shellCommandToRun(from: text) {
            let action = AssistantAction(type: "run_shell_command", payload: ["command": .string(shellCommand)])
            let risk = ShellCommandPolicy().risk(for: shellCommand)
            return .needsConfirmation(
                ConfirmationRequest(
                    risk: risk,
                    title: "Run command?",
                    description: shellCommand,
                    action: action,
                    requiresTypedConfirmation: risk == .red
                )
            )
        }

        if let shortcut = shortcutToOpen(from: text, shortcuts: shortcuts) {
            return .handled(
                response: "Opening \(shortcut.name).",
                action: AssistantAction(type: "open_url", payload: ["url": .string(shortcut.url.absoluteString), "label": .string(shortcut.name)])
            )
        }

        if let website = websiteToOpen(from: text) {
            return .handled(
                response: "Opening \(website.label).",
                action: AssistantAction(type: "open_url", payload: ["url": .string(website.url.absoluteString), "label": .string(website.label)])
            )
        }

        if let appName = appNameToOpen(from: text) {
            return .handled(
                response: "Opening \(appName).",
                action: AssistantAction(type: "open_app", payload: ["name": .string(appName)])
            )
        }

        return .notMatched
    }

    public func normalize(_ transcript: String) -> String {
        var text = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")

        let fillerPrefixes = ["hey jarvis ", "jarvis ", "please ", "can you ", "could you "]
        var removedPrefix = true
        while removedPrefix {
            removedPrefix = false
            for prefix in fillerPrefixes where text.hasPrefix(prefix) {
                text.removeFirst(prefix.count)
                removedPrefix = true
                break
            }
        }

        let fillerWords = ["um", "uh", "like"]
        text = text
            .split(separator: " ")
            .filter { !fillerWords.contains(String($0)) }
            .joined(separator: " ")

        return text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appNameToOpen(from text: String) -> String? {
        guard let rawName = openTarget(from: text) else { return nil }
        let aliases: [String: String] = [
            "chrome": "Google Chrome",
            "google chrome": "Google Chrome",
            "safari": "Safari",
            "spotify": "Spotify",
            "messages": "Messages",
            "mail": "Mail",
            "calendar": "Calendar",
            "notes": "Notes",
            "reminders": "Reminders",
            "maps": "Maps",
            "photos": "Photos",
            "facetime": "FaceTime",
            "terminal": "Terminal",
            "settings": "System Settings",
            "system settings": "System Settings",
            "calculator": "Calculator",
            "vscode": "Visual Studio Code",
            "vs code": "Visual Studio Code",
            "code": "Visual Studio Code"
        ]

        if let alias = aliases[rawName] {
            return alias
        }
        guard rawName.range(of: #"^[a-z0-9][a-z0-9\s-]{1,48}$"#, options: .regularExpression) != nil else {
            return nil
        }
        guard !rawName.contains(".") else { return nil }
        return rawName
            .split(separator: " ")
            .map { word in
                let lower = String(word)
                return lower == "tv" ? "TV" : lower.capitalized
            }
            .joined(separator: " ")
    }

    private func shortcutToOpen(from text: String, shortcuts: [ShortcutConfig]) -> ShortcutConfig? {
        guard let requested = openTarget(from: text) else { return nil }

        return shortcuts.first { shortcut in
            let name = shortcut.name.lowercased()
            return requested == name || requested.contains(name) || name.contains(requested)
        }
    }

    private struct WebsiteTarget {
        var label: String
        var url: URL
    }

    private func websiteToOpen(from text: String) -> WebsiteTarget? {
        guard let requested = openTarget(from: text) else { return nil }
        let cleaned = cleanWebsiteTarget(requested)
        guard !cleaned.isEmpty else { return nil }

        let aliases: [String: (label: String, url: String)] = [
            "amazon": ("Amazon", "https://www.amazon.com"),
            "apple": ("Apple", "https://www.apple.com"),
            "best buy": ("Best Buy", "https://www.bestbuy.com"),
            "bestbuy": ("Best Buy", "https://www.bestbuy.com"),
            "costco": ("Costco", "https://www.costco.com"),
            "google": ("Google", "https://www.google.com"),
            "youtube": ("YouTube", "https://www.youtube.com"),
            "github": ("GitHub", "https://github.com"),
            "chatgpt": ("ChatGPT", "https://chatgpt.com"),
            "openai": ("OpenAI", "https://openai.com"),
            "gmail": ("Gmail", "https://mail.google.com"),
            "calendar": ("Google Calendar", "https://calendar.google.com"),
            "reddit": ("Reddit", "https://www.reddit.com"),
            "twitter": ("X", "https://x.com"),
            "x": ("X", "https://x.com"),
            "linkedin": ("LinkedIn", "https://www.linkedin.com"),
            "netflix": ("Netflix", "https://www.netflix.com")
        ]

        if let alias = aliases[cleaned] {
            return URL(string: alias.url).map { WebsiteTarget(label: alias.label, url: $0) }
        }

        guard looksLikeDomain(cleaned) else { return nil }
        let compact = cleaned.replacingOccurrences(of: " ", with: "")
        let urlText = compact.hasPrefix("http://") || compact.hasPrefix("https://") ? compact : "https://\(compact)"
        guard let url = URL(string: urlText), url.host != nil else { return nil }
        return WebsiteTarget(label: label(for: url), url: url)
    }

    private func shellCommandToRun(from text: String) -> String? {
        let prefixes = [
            "run shell command ",
            "run terminal command ",
            "execute shell command ",
            "execute terminal command ",
            "run command ",
            "execute command "
        ]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let command = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return command.isEmpty ? nil : command
        }
        return nil
    }

    private func openTarget(from text: String) -> String? {
        let prefixes = [
            "open up ",
            "open the website ",
            "open website ",
            "open site ",
            "open ",
            "launch ",
            "go to ",
            "navigate to ",
            "visit ",
            "bring up ",
            "pull up "
        ]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let target = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return target.isEmpty ? nil : target
        }
        return nil
    }

    private func cleanWebsiteTarget(_ target: String) -> String {
        target
            .replacingOccurrences(of: " dot ", with: ".")
            .replacingOccurrences(of: " slash ", with: "/")
            .replacingOccurrences(of: " colon ", with: ":")
            .replacingOccurrences(of: #"^the\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+(website|site|webpage)$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeDomain(_ target: String) -> Bool {
        let compact = target.replacingOccurrences(of: " ", with: "")
        guard compact.contains(".") else { return false }
        return compact.range(of: #"^(https?://)?([a-z0-9-]+\.)+[a-z]{2,}(/[^\s]*)?$"#, options: .regularExpression) != nil
    }

    private func label(for url: URL) -> String {
        let host = (url.host ?? url.absoluteString)
            .replacingOccurrences(of: #"^www\."#, with: "", options: [.regularExpression, .caseInsensitive])
        let first = host.split(separator: ".").first.map(String.init) ?? host
        let known: [String: String] = [
            "amazon": "Amazon",
            "apple": "Apple",
            "bestbuy": "Best Buy",
            "costco": "Costco",
            "google": "Google",
            "youtube": "YouTube",
            "github": "GitHub",
            "chatgpt": "ChatGPT",
            "openai": "OpenAI"
        ]
        return known[first.lowercased()] ?? first.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
