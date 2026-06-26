import Foundation

public struct ActionRegistry: Sendable {
    public init() {}

    public func risk(for action: AssistantAction) -> ActionRisk {
        switch action.type {
        case "open_url", "open_urls", "open_app",
             "spotify_play", "spotify_pause", "spotify_next", "spotify_previous", "spotify_current_track",
             "system_volume_up", "system_volume_down", "system_mute",
             "stop_tts", "cancel", "read_selected_text", "read_current_page", "summarize":
            return .green
        case "run_shell_command":
            return ShellCommandPolicy().risk(for: action.payload["command"]?.stringValue ?? "")
        case "save_memory", "draft_email", "draft_message", "create_calendar_event", "edit_file", "create_file":
            return .yellow
        case "delete_files", "sudo_command", "send_message", "send_email", "payment", "expose_api_keys":
            return .red
        default:
            return .yellow
        }
    }

    public func confirmation(for action: AssistantAction) -> ConfirmationRequest? {
        let actionRisk = risk(for: action)
        switch actionRisk {
        case .green:
            return nil
        case .yellow:
            return ConfirmationRequest(
                risk: .yellow,
                title: title(for: action),
                description: "Review and confirm before Jarvis runs this action.",
                action: action
            )
        case .red:
            return ConfirmationRequest(
                risk: .red,
                title: title(for: action),
                description: "This is a sensitive action. Type confirm before continuing.",
                action: action,
                requiresTypedConfirmation: true
            )
        }
    }

    private func title(for action: AssistantAction) -> String {
        switch action.type {
        case "draft_message": "Draft message?"
        case "draft_email": "Draft email?"
        case "send_message": "Send message?"
        case "send_email": "Send email?"
        case "run_shell_command": "Run command?"
        case "save_memory": "Save memory?"
        default: "Run action?"
        }
    }

}
