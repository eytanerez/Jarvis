import Darwin
import Foundation
import JarvisCore

@MainActor
public final class ActionExecutor {
    private let appLauncher = AppLauncher()
    private let urlLauncher = URLLauncher()
    private let spotify = SpotifyController()
    private let audio = SystemAudioController()

    public init() {}

    public func execute(_ action: AssistantAction) async -> StructuredResponse {
        switch action.type {
        case "open_app":
            let name = action.payload["name"]?.stringValue ?? ""
            let ok = await appLauncher.openApp(named: name)
            return StructuredResponse(
                answer: ok ? "Opening \(name)." : "I couldn't open \(name).",
                speak: ok ? "Opening \(name)." : "I couldn't open \(name).",
                modelUsed: "Local action",
                metadata: ResponseMetadata(route: "direct_command", actionCount: ok ? 1 : 0)
            )
        case "open_url":
            guard let urlString = action.payload["url"]?.stringValue, let url = URL(string: urlString) else {
                return StructuredResponse(
                    answer: "That URL was invalid.",
                    modelUsed: "Local action",
                    metadata: ResponseMetadata(route: "direct_command")
                )
            }
            let ok = urlLauncher.openURL(url)
            let label = action.payload["label"]?.stringValue ?? displayName(for: url)
            return StructuredResponse(
                answer: ok ? "Opening \(label)." : "I couldn't open \(label).",
                speak: ok ? "Opening \(label)." : "I couldn't open \(label).",
                modelUsed: "Local action",
                metadata: ResponseMetadata(route: "direct_command", actionCount: ok ? 1 : 0)
            )
        case "open_urls":
            let urls = action.payload["urls"]?.arrayValue?.compactMap { $0.stringValue.flatMap(URL.init(string:)) } ?? []
            let newWindow = {
                if case .bool(let value)? = action.payload["newWindow"] { return value }
                return true
            }()
            let opened = urlLauncher.openURLs(urls, newWindow: newWindow)
            return StructuredResponse(
                answer: "Opening \(opened) links.",
                speak: "Opening \(opened) links.",
                modelUsed: "Local action",
                metadata: ResponseMetadata(route: "direct_command", actionCount: opened)
            )
        case "spotify_play":
            return localActionResponse(spotify.play())
        case "spotify_pause":
            return localActionResponse(spotify.pause())
        case "spotify_next":
            return localActionResponse(spotify.next())
        case "spotify_previous":
            return localActionResponse(spotify.previous())
        case "spotify_current_track":
            return localActionResponse(spotify.currentTrack())
        case "system_volume_up":
            return localActionResponse(audio.volumeUp())
        case "system_volume_down":
            return localActionResponse(audio.volumeDown())
        case "system_mute":
            return localActionResponse(audio.mute())
        case "run_shell_command":
            let command = action.payload["command"]?.stringValue ?? ""
            return await runShellCommand(command)
        case "draft_message":
            return StructuredResponse(answer: "Draft is ready. I’ll wait for you before anything gets sent.", modelUsed: "Local action")
        case "save_memory":
            return StructuredResponse(answer: "Memory action accepted.", modelUsed: "Local action")
        case "cancel":
            return StructuredResponse(answer: "Canceled.", modelUsed: "Local action")
        default:
            return StructuredResponse(answer: "I don't know how to run \(action.type) yet.", modelUsed: "Local action")
        }
    }

    private func localActionResponse(_ answer: String) -> StructuredResponse {
        StructuredResponse(
            answer: answer,
            speak: answer,
            modelUsed: "Local action",
            metadata: ResponseMetadata(route: "direct_command", actionCount: 1)
        )
    }

    private func displayName(for url: URL) -> String {
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

    private func runShellCommand(_ command: String) async -> StructuredResponse {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return StructuredResponse(
                answer: "That command was empty.",
                speak: "That command was empty.",
                modelUsed: "Local action",
                metadata: ResponseMetadata(route: "direct_command")
            )
        }

        let result = await Task.detached(priority: .userInitiated) {
            runShellCommandDetached(trimmed)
        }.value

        let body = shellCommandAnswer(command: trimmed, result: result)
        return StructuredResponse(
            answer: body,
            speak: result.exitCode == 0 ? "Command finished." : "The command exited with code \(result.exitCode).",
            modelUsed: "Local action",
            metadata: ResponseMetadata(route: "direct_command", warnings: result.timedOut ? ["Command timed out after 20 seconds."] : [], actionCount: 1)
        )
    }
}

private struct ShellCommandResult: Sendable {
    var exitCode: Int32
    var output: String
    var error: String
    var timedOut: Bool
}

private func runShellCommandDetached(_ command: String) -> ShellCommandResult {
    let process = Process()
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("JarvisCommand-\(UUID().uuidString).out")
    let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("JarvisCommand-\(UUID().uuidString).err")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    FileManager.default.createFile(atPath: errorURL.path, contents: nil)
    guard let outputHandle = try? FileHandle(forWritingTo: outputURL),
          let errorHandle = try? FileHandle(forWritingTo: errorURL) else {
        return ShellCommandResult(exitCode: -1, output: "", error: "Could not create temporary command output files.", timedOut: false)
    }
    defer {
        try? outputHandle.close()
        try? errorHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.removeItem(at: errorURL)
    }

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", command]
    process.standardOutput = outputHandle
    process.standardError = errorHandle

    do {
        try process.run()
    } catch {
        return ShellCommandResult(exitCode: -1, output: "", error: error.localizedDescription, timedOut: false)
    }

    let deadline = Date().addingTimeInterval(20)
    var timedOut = false
    while process.isRunning {
        if Date() >= deadline {
            timedOut = true
            process.terminate()
            Thread.sleep(forTimeInterval: 0.25)
            if process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
            }
            break
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
    process.waitUntilExit()
    try? outputHandle.synchronize()
    try? errorHandle.synchronize()
    let stdout = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
    let stderr = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
    return ShellCommandResult(exitCode: process.terminationStatus, output: stdout, error: stderr, timedOut: timedOut)
}

private func shellCommandAnswer(command: String, result: ShellCommandResult) -> String {
    let status = result.timedOut ? "timed out" : "exited with code \(result.exitCode)"
    let combined = [result.output, result.error]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    let clipped = combined.count > 1_200 ? String(combined.prefix(1_200)) + "\n..." : combined
    if clipped.isEmpty {
        return "Command \(status): \(command)"
    }
    return "Command \(status): \(command)\n\n\(clipped)"
}
