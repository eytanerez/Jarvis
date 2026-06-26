import Darwin
import Foundation
import JarvisCore

public final class BrainProcessManager: @unchecked Sendable {
    public let port: Int
    public let token: String
    private var process: Process?
    private var standardOutputPipe: Pipe?
    private var standardErrorPipe: Pipe?
    private let keychain: KeychainManager
    private var settings: AppSettings?

    public init(port: Int? = nil, token: String = UUID().uuidString, keychain: KeychainManager = KeychainManager(), settings: AppSettings? = nil) {
        self.port = port ?? Self.availablePort(preferred: 8765)
        self.token = token
        self.keychain = keychain
        self.settings = settings
    }

    public func startIfNeeded(settings: AppSettings? = nil) {
        if let settings {
            self.settings = settings
        }
        guard process?.isRunning != true else { return }
        let brainDirectory = findBrainDirectory()
        let launchScript = brainDirectory.appendingPathComponent("run_brain.py")
        guard FileManager.default.fileExists(atPath: launchScript.path) else {
            return
        }
        terminateStaleBrainProcesses(launchScript: launchScript)

        let process = Process()
        process.executableURL = pythonExecutable(in: brainDirectory)
        process.arguments = [launchScript.path]
        process.currentDirectoryURL = brainDirectory
        process.environment = environment()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        installDrain(for: outputPipe)
        installDrain(for: errorPipe)
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] _ in
            self?.clearPipeDrains()
        }

        do {
            try process.run()
            self.process = process
            standardOutputPipe = outputPipe
            standardErrorPipe = errorPipe
        } catch {
            clearPipeDrains()
            self.process = nil
        }
    }

    public func stop() {
        let launchScript = findBrainDirectory().appendingPathComponent("run_brain.py")
        process?.terminate()
        process = nil
        clearPipeDrains()
        terminateStaleBrainProcesses(launchScript: launchScript)
    }

    public func restart(settings: AppSettings? = nil) {
        if let settings {
            self.settings = settings
        }
        stop()
        Thread.sleep(forTimeInterval: 0.2)
        startIfNeeded()
    }

    private func findBrainDirectory() -> URL {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("brain"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("brain")
    }

    private func pythonExecutable(in brainDirectory: URL) -> URL {
        let venvPython = brainDirectory.appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            return venvPython
        }
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/python3.12") {
            return URL(fileURLWithPath: "/opt/homebrew/bin/python3.12")
        }
        return URL(fileURLWithPath: "/usr/bin/python3")
    }

    private func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        clearProviderSecrets(in: &env)
        env["JARVIS_BRAIN_TOKEN"] = token
        env["JARVIS_BRAIN_PORT"] = String(port)
        env["JARVIS_BRAIN_HOME"] = applicationSupportPath()
        if let settings {
            env["JARVIS_PROVIDER_ORDER"] = settings.providerFallbackOrder.map(\.rawValue).joined(separator: ",")
            env["JARVIS_CONTEXT_PRIVACY_LEVEL"] = String(settings.context.privacyLevel.rawValue)
            env["JARVIS_FILE_INDEX_ENABLED"] = settings.context.fileIndexEnabled ? "1" : "0"
            env["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = settings.context.approvedFolders.joined(separator: "\n")
            env["JARVIS_FILE_INDEX_EXCLUSIONS"] = settings.context.exclusions.joined(separator: "\n")
            env["JARVIS_FILE_INDEX_ALLOW_CLOUD"] = settings.context.allowCloudFileContents ? "1" : "0"
            env["JARVIS_LOCAL_ONLY_MODE"] = settings.context.localOnlyMode ? "1" : "0"
        }

        if let provider = providerConfig(for: .openAI) {
            env["JARVIS_OPENAI_FAST_MODEL"] = provider.fastModel
            env["JARVIS_OPENAI_SMART_MODEL"] = provider.smartModel
            env["JARVIS_OPENAI_REASONING_MODEL"] = provider.smartModel
        }
        if let provider = providerConfig(for: .anthropic) {
            env["JARVIS_ANTHROPIC_FAST_MODEL"] = provider.fastModel
            env["JARVIS_ANTHROPIC_SMART_MODEL"] = provider.smartModel
            env["JARVIS_ANTHROPIC_REASONING_MODEL"] = provider.smartModel
        }
        if let provider = providerConfig(for: .gemini) {
            env["JARVIS_GEMINI_FAST_MODEL"] = provider.fastModel
            env["JARVIS_GEMINI_SMART_MODEL"] = provider.smartModel
            env["JARVIS_GEMINI_REASONING_MODEL"] = provider.smartModel
        }
        env["JARVIS_WEB_SEARCH_MODE"] = settings?.webSearch.mode.rawValue ?? WebSearchMode.demo.rawValue

        if providerIsEnabled(.openAI), let key = try? keychain.apiKey(for: .openAI) {
            env["OPENAI_API_KEY"] = key
            env["JARVIS_OPENAI_API_KEY"] = key
        }
        if providerIsEnabled(.anthropic), let key = try? keychain.apiKey(for: .anthropic) {
            env["ANTHROPIC_API_KEY"] = key
            env["JARVIS_ANTHROPIC_API_KEY"] = key
        }
        if providerIsEnabled(.gemini), let key = try? keychain.apiKey(for: .gemini) {
            env["GEMINI_API_KEY"] = key
            env["GOOGLE_API_KEY"] = key
            env["JARVIS_GEMINI_API_KEY"] = key
        }
        return env
    }

    private func clearProviderSecrets(in env: inout [String: String]) {
        [
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "GEMINI_API_KEY",
            "GOOGLE_API_KEY",
            "JARVIS_OPENAI_API_KEY",
            "JARVIS_ANTHROPIC_API_KEY",
            "JARVIS_GEMINI_API_KEY"
        ].forEach { env.removeValue(forKey: $0) }
    }

    private func providerConfig(for id: ProviderID) -> ProviderConfig? {
        settings?.providers.first { $0.id == id }
    }

    private func providerIsEnabled(_ id: ProviderID) -> Bool {
        providerConfig(for: id)?.enabled ?? true
    }

    private func applicationSupportPath() -> String {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (base ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("JarvisNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.path
    }

    private func installDrain(for pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
    }

    private func clearPipeDrains() {
        standardOutputPipe?.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe?.fileHandleForReading.readabilityHandler = nil
        standardOutputPipe = nil
        standardErrorPipe = nil
    }

    private func terminateStaleBrainProcesses(launchScript: URL) {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", launchScript.path]
        let output = Pipe()
        pgrep.standardOutput = output
        pgrep.standardError = Pipe()

        do {
            try pgrep.run()
            pgrep.waitUntilExit()
        } catch {
            return
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return }
        let currentProcessID = process?.processIdentifier
        for line in text.split(whereSeparator: \.isNewline) {
            guard let pid = Int32(line.trimmingCharacters(in: .whitespacesAndNewlines)),
                  pid != currentProcessID else {
                continue
            }
            Darwin.kill(pid, SIGTERM)
        }
    }

    private static func availablePort(preferred: Int) -> Int {
        if portIsAvailable(preferred) {
            return preferred
        }
        for _ in 0..<32 {
            let candidate = Int.random(in: 20000...60999)
            if portIsAvailable(candidate) {
                return candidate
            }
        }
        return preferred
    }

    private static func portIsAvailable(_ port: Int) -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return false }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                    && listen(socketDescriptor, 1) == 0
            }
        }
    }
}
