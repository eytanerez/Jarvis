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
    try expect(settings.voice.f5CfgStrength == 2.0, "Old voice settings should default F5-TTS CFG strength")
}

func runScheduleContextTests() throws {
    let event = ScheduleItemContext(
        id: "event-1",
        kind: "event",
        title: "Investor check-in",
        calendarTitle: "Work",
        start: Date(timeIntervalSince1970: 1_782_492_000),
        end: Date(timeIntervalSince1970: 1_782_495_600),
        participantNames: ["David"]
    )
    let reminder = ScheduleItemContext(
        id: "reminder-1",
        kind: "reminder",
        title: "Send deck",
        start: Date(timeIntervalSince1970: 1_782_499_200),
        completed: false
    )
    let schedule = ScheduleContext(
        generatedAt: Date(timeIntervalSince1970: 1_782_488_400),
        calendarAuthorization: "fullAccess",
        reminderAuthorization: "fullAccess",
        events: [event],
        reminders: [reminder]
    )
    try expect(schedule.hasAnyEntries, "Schedule context should report entries")

    let encoded = try JSONEncoder().encode(schedule)
    let decoded = try JSONDecoder().decode(ScheduleContext.self, from: encoded)
    try expect(decoded.events.first?.title == "Investor check-in", "Schedule event did not round-trip")
    try expect(decoded.reminders.first?.completed == false, "Schedule reminder completion did not round-trip")

    let previewJSON = """
    {
      "agent": {
        "id": "daily_brief",
        "name": "Daily Brief",
        "description": "Short opt-in summary from enabled local sources.",
        "type": "scheduled",
        "enabled": false,
        "time": "08:30",
        "timezone": "America/New_York",
        "sources": {"calendar": true, "reminders": true},
        "requiresOptIn": true,
        "lastRunAt": null,
        "nextRunAt": "2026-06-27T08:30:00-04:00",
        "updatedAt": "2026-06-26T12:00:00-04:00"
      },
      "answer": "Daily brief preview",
      "speak": "Daily brief preview ready.",
      "sourcesUsed": ["calendar", "reminders"],
      "metadata": {"route": "scheduled_agent", "mode": "daily_brief", "contextAvailable": true}
    }
    """
    let preview = try JSONDecoder().decode(ScheduledAgentPreviewReport.self, from: Data(previewJSON.utf8))
    try expect(preview.agent.requiresOptIn, "Daily brief should remain opt-in")
    try expect(preview.sourcesUsed == ["calendar", "reminders"], "Scheduled preview sources did not decode")
    try expect(preview.metadata?.route == "scheduled_agent", "Scheduled preview metadata did not decode")

    let dueAgentJSON = """
    {
      "id": "daily_brief",
      "name": "Daily Brief",
      "description": "Short opt-in summary from enabled local sources.",
      "type": "scheduled",
      "enabled": true,
      "time": "08:30",
      "timezone": "America/New_York",
      "sources": {"calendar": true, "reminders": true},
      "requiresOptIn": true,
      "lastRunAt": null,
      "nextRunAt": "2026-06-27T08:30:00-04:00",
      "updatedAt": "2026-06-26T12:00:00-04:00"
    }
    """
    var dueAgent = try JSONDecoder().decode(ScheduledAgent.self, from: Data(dueAgentJSON.utf8))
    let isoFormatter = ISO8601DateFormatter()
    guard let afterScheduledTime = isoFormatter.date(from: "2026-06-26T09:00:00-04:00"),
          let beforeScheduledTime = isoFormatter.date(from: "2026-06-26T08:00:00-04:00") else {
        throw HarnessError.failure("Failed to build scheduled agent test dates")
    }
    try expect(dueAgent.isDue(now: afterScheduledTime), "Enabled daily brief should be due after its scheduled time")
    try expect(!dueAgent.isDue(now: beforeScheduledTime), "Daily brief should not be due before its scheduled time")

    dueAgent.lastRunAt = "2026-06-26T08:31:00-04:00"
    try expect(dueAgent.hasRun(on: afterScheduledTime), "Daily brief should detect same-day run")
    try expect(!dueAgent.isDue(now: afterScheduledTime), "Daily brief should not repeat after running that day")

    dueAgent.enabled = false
    dueAgent.lastRunAt = nil
    try expect(!dueAgent.isDue(now: afterScheduledTime), "Disabled daily brief should not be due")
}

func runSkillRunHistoryTests() throws {
    let json = """
    {
      "runs": [
        {
          "id": "run-1",
          "timestamp": "2026-06-26T12:00:00Z",
          "kind": "local_skill",
          "name": "time.now",
          "route": "local_skill",
          "status": "completed",
          "mode": "quick_assistant",
          "intent": "quick_answer",
          "riskLevel": "green",
          "requiresConfirmation": false,
          "loadedSkills": [],
          "missingSkills": [],
          "warnings": [],
          "inputSummary": {"contextAvailable": false, "actionCount": 0},
          "metadata": {"modelRoute": "local_skill", "privacyLevel": "local"}
        }
      ]
    }
    """
    let report = try JSONDecoder().decode(SkillRunHistoryReport.self, from: Data(json.utf8))
    try expect(report.runs.first?.name == "time.now", "Skill run history name did not decode")
    try expect(report.runs.first?.kind == "local_skill", "Skill run history kind did not decode")
    try expect(report.runs.first?.requiresConfirmation == false, "Skill run history confirmation flag did not decode")
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
    try runScheduleContextTests()
    try runSkillRunHistoryTests()
    try runResponseComposerTests()
    print("JarvisTestHarness passed")
} catch {
    fputs("JarvisTestHarness failed: \(error)\n", stderr)
    exit(1)
}
