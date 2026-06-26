import Foundation
import JarvisCore
import JarvisMac

enum HarnessError: Error, CustomStringConvertible {
    case failure(String)

    var description: String {
        switch self {
        case .failure(let message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw HarnessError.failure(message)
    }
}

func runCommandMatcherTests() throws {
    let match = CommandMatcher().match("please open Spotify")
    guard case .handled(let response, let action?) = match else {
        throw HarnessError.failure("Expected Spotify command to be handled")
    }
    try expect(response == "Opening Spotify.", "Unexpected Spotify response")
    try expect(action.type == "open_app", "Unexpected Spotify action type")
    try expect(action.payload["name"]?.stringValue == "Spotify", "Unexpected Spotify app name")

    let shortcut = ShortcutConfig(name: "Calibre dev", url: URL(string: "https://calibre.test")!)
    let shortcutMatch = CommandMatcher().match("open calibre dev", shortcuts: [shortcut])
    guard case .handled(_, let shortcutAction?) = shortcutMatch else {
        throw HarnessError.failure("Expected shortcut command to be handled")
    }
    try expect(shortcutAction.type == "open_url", "Unexpected shortcut action type")
    try expect(shortcutAction.payload["url"]?.stringValue == "https://calibre.test", "Unexpected shortcut URL")

    let websiteMatch = CommandMatcher().match("open amazon")
    guard case .handled(_, let websiteAction?) = websiteMatch else {
        throw HarnessError.failure("Expected website command to be handled")
    }
    try expect(websiteAction.type == "open_url", "Unexpected website action type")
    try expect(websiteAction.payload["url"]?.stringValue == "https://www.amazon.com", "Unexpected website URL")

    let spokenDomainMatch = CommandMatcher().match("go to amazon dot com")
    guard case .handled(_, let domainAction?) = spokenDomainMatch else {
        throw HarnessError.failure("Expected spoken domain command to be handled")
    }
    try expect(domainAction.payload["url"]?.stringValue == "https://amazon.com", "Unexpected spoken domain URL")

    let shellMatch = CommandMatcher().match("run command pwd")
    guard case .needsConfirmation(let shellConfirmation) = shellMatch else {
        throw HarnessError.failure("Expected shell command to need confirmation")
    }
    try expect(shellConfirmation.action.type == "run_shell_command", "Unexpected shell action type")
    try expect(shellConfirmation.action.payload["command"]?.stringValue == "pwd", "Unexpected shell command payload")
}

func runLocalAnswerTests() throws {
    try expect(LocalAnswerRouter().answer("What's 18% of 240?") == .answer("43.2"), "Percent answer failed")
    guard case .escalate = LocalAnswerRouter().answer("Research this") else {
        throw HarnessError.failure("Research should escalate")
    }
}

func runIntentRouterTests() throws {
    let router = IntentRouter()
    try expect(router.classify("Remember that we use mem0") == .memory, "Explicit memory should classify as memory")
    try expect(router.classify("Find the top 5 places to buy an iPad") == .web, "Web search should classify as web")
    try expect(router.classify("Draft a message to Moshe saying I'll call later") == .action, "Message drafts should classify as action")
    try expect(router.classify("Summarize this page for me") == .screenContext, "Page summary should require screen context")
    try expect(router.classify("Explain why the sky is blue") == .general, "General explanations should classify as general")
    try expect(router.mode(for: "Compare these two options", hasBrowserContext: false) == .smart, "Compare should be smart mode")
    try expect(router.mode(for: "What time is it", hasBrowserContext: false) == .fast, "Simple ask should be fast mode")
}

func runShellCommandPolicyTests() throws {
    let policy = ShellCommandPolicy()
    try expect(policy.risk(for: "pwd") == .yellow, "Allowlisted command should be yellow")
    try expect(policy.risk(for: "ls -la /tmp") == .yellow, "Allowlisted command with args should be yellow")
    try expect(policy.risk(for: "rm -rf ~") == .red, "Unknown command should be red")
    try expect(policy.risk(for: "sudo reboot") == .red, "sudo should be red")
    try expect(policy.risk(for: "echo hi; rm -rf ~") == .red, "Chained command should be red")
    try expect(policy.risk(for: "cat secrets | mail bob") == .red, "Piped command should be red")
    try expect(policy.risk(for: "echo $(whoami)") == .red, "Command substitution should be red")
    try expect(policy.risk(for: "") == .red, "Empty command should be red")
    try expect(policy.requiresTypedConfirmation(for: "rm -rf /"), "Dangerous command should require typed confirmation")
    try expect(!policy.requiresTypedConfirmation(for: "pwd"), "Safe command should not require typed confirmation")
}

func runFollowUpPhrasesTests() throws {
    try expect(FollowUpPhrases.isDone("No thanks"), "No thanks should be a done reply")
    try expect(FollowUpPhrases.isDone("That's all, Jarvis."), "Wake word + punctuation should still match done")
    try expect(FollowUpPhrases.isDone("I'm done"), "Contraction should normalize to a done reply")
    try expect(FollowUpPhrases.isDone("I don't want to talk anymore"), "Natural sign-off should be a done reply")
    try expect(FollowUpPhrases.isDone("Thank you so much"), "Thanks-only sign-off should be a done reply")
    try expect(!FollowUpPhrases.isDone("open my email"), "A real request is not a done reply")
    try expect(FollowUpPhrases.normalized("That’s it!") == "thats it", "Normalization should strip punctuation and contractions")
}

func runFollowUpTests() throws {
    let session = SessionStore(lastResults: [
        StructuredResult(id: "1", rank: 1, name: "Apple", url: URL(string: "https://apple.com")),
        StructuredResult(id: "2", rank: 2, name: "Best Buy", url: URL(string: "https://bestbuy.com")),
        StructuredResult(id: "3", rank: 3, name: "Costco", url: URL(string: "https://costco.com"))
    ])

    let resolution = FollowUpResolver().resolve("Open the Costco one", session: session)
    guard case .action(let action, let selected?) = resolution else {
        throw HarnessError.failure("Expected named result open action")
    }
    try expect(selected.name == "Costco", "Wrong selected result")
    try expect(action.payload["url"]?.stringValue == "https://costco.com", "Wrong selected URL")

    let compare = FollowUpResolver().resolve("Compare the first two", session: session)
    guard case .compare(let results) = compare else {
        throw HarnessError.failure("Expected compare resolution")
    }
    try expect(results.map(\.name) == ["Apple", "Best Buy"], "Wrong compare results")
}

func runRiskPolicyTests() throws {
    try expect(ActionRegistry().risk(for: AssistantAction(type: "open_url")) == .green, "Open URL should be green")
    let confirmation = ActionRegistry().confirmation(for: AssistantAction(type: "send_message"))
    try expect(confirmation?.risk == .red, "Send message should be red")
    try expect(confirmation?.requiresTypedConfirmation == true, "Send message should require typed confirmation")
}

func runCodableTests() throws {
    let json = """
    {
      "answer": "Found options.",
      "speak": "Found five.",
      "results": [{"id": "result_1", "rank": 1, "name": "Apple", "url": "https://apple.com", "metadata": {}}],
      "actions": [{"id": "action_1", "type": "open_url", "payload": {"url": "https://apple.com"}}],
      "memoryUpdates": [],
      "requiresConfirmation": false,
      "confirmation": null
    }
    """
    let response = try JSONDecoder().decode(StructuredResponse.self, from: Data(json.utf8))
    try expect(response.results.first?.name == "Apple", "Structured result did not decode")
    try expect(response.actions.first?.payload["url"]?.stringValue == "https://apple.com", "Action payload did not decode")
}

func runKeychainTests() throws {
    let keychain = KeychainManager(service: "com.eytanerez.JarvisNotch.tests.\(UUID().uuidString)")
    try expect(!keychain.hasAPIKey(for: .openAI), "Keychain presence should start false")
    try keychain.setAPIKey("test-key", for: .openAI)
    try expect(keychain.hasAPIKey(for: .openAI), "Keychain presence should be true after save")
    let storedKey = try keychain.apiKey(for: .openAI)
    try expect(storedKey == "test-key", "Keychain read failed")
    try keychain.deleteAPIKey(for: .openAI)
    try expect(!keychain.hasAPIKey(for: .openAI), "Keychain presence should be false after delete")
    let deletedKey = try keychain.apiKey(for: .openAI)
    try expect(deletedKey == nil, "Keychain delete failed")
}

func runSettingsMigrationTests() throws {
    let json = """
    {
      "providers": [
        {
          "id": "openai",
          "enabled": true,
          "baseURL": "https://api.openai.com/v1",
          "defaultModel": "gpt-5.5",
          "fastModel": "gpt-5.5",
          "reasoningModel": "gpt-5-mini",
          "visionModel": "gpt-5-mini"
        }
      ],
      "providerFallbackOrder": ["openai"],
      "shortcuts": [],
      "voice": {"voiceIdentifier": null, "spokenSummaryLimit": 220},
      "session": {"followUpContextEnabled": true, "idleTimeoutMinutes": 20},
      "memory": {"enabled": true, "explicitOnly": true, "paused": false}
    }
    """
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    try expect(settings.providers.first?.fastModel == "gpt-5.5", "Old fast model did not decode")
    try expect(settings.providers.first?.smartModel == "gpt-5-mini", "Old reasoning model did not migrate into smart model")
    try expect(settings.voice.ttsEngine == .kokoro, "Old voice settings should default to Kokoro")
    try expect(settings.voice.kokoroVoice == "af_heart", "Old voice settings should default Kokoro voice")
    try expect(settings.personality.name == "Jarvis", "Old settings should default personality")
    try expect(settings.voice.chatterboxExaggeration == 0.45, "Old voice settings should default Chatterbox exaggeration")
}

func runResponseComposerTests() throws {
    let spoken = ResponseComposer.sanitizeSpokenText("**Open** www.amazon.com and `run` *this*.")
    try expect(!spoken.contains("*"), "Spoken text should remove markdown asterisks")
    try expect(!spoken.contains("www.amazon.com"), "Spoken text should replace raw URLs")
    try expect(spoken.contains("on Amazon"), "Spoken text should name known sites")
}

do {
    try runCommandMatcherTests()
    try runLocalAnswerTests()
    try runIntentRouterTests()
    try runShellCommandPolicyTests()
    try runFollowUpPhrasesTests()
    try runFollowUpTests()
    try runRiskPolicyTests()
    try runCodableTests()
    try runKeychainTests()
    try runSettingsMigrationTests()
    try runResponseComposerTests()
    print("JarvisTestHarness passed")
} catch {
    fputs("JarvisTestHarness failed: \(error)\n", stderr)
    exit(1)
}
