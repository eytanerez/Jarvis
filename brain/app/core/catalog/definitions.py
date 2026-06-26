from __future__ import annotations

from typing import List

from .models import SkillDef

# Secrets a Spotify skill declares it needs. These are *names*, never values;
# real tokens live only in runtime secrets / keychain-backed storage.
SPOTIFY_SECRETS = ["SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET", "SPOTIFY_REFRESH_TOKEN"]


def _d(path: str, desc: str, risk: str = "green", source: str = "brain_service", **kw) -> SkillDef:
    category, name = path.split("/", 1)
    return SkillDef(category=category, name=name, description=desc[:60], risk_level=risk, source=source, **kw)


def _catalog() -> List[SkillDef]:
    defs: List[SkillDef] = []

    # -- Assistant ---------------------------------------------------------
    defs += [
        _d("assistant/jarvis-explain-capabilities", "Explain live Jarvis capabilities and limits", "green", "brain_service"),
        _d("assistant/jarvis-help", "Explain how to use Jarvis", "green", "brain_service"),
        _d("assistant/jarvis-status", "Show provider, skill, TTS, and context status", "green", "brain_service"),
        _d("assistant/jarvis-debug-trace", "Explain why Jarvis chose a route", "green", "brain_service"),
        _d("assistant/jarvis-go-offline", "Switch Jarvis to local-only mode", "yellow", "brain_service"),
        _d("assistant/jarvis-go-online", "Re-enable cloud provider routing", "yellow", "brain_service"),
        _d("assistant/jarvis-change-mode", "Switch assistant mode", "green", "brain_service"),
        # Kept canonical (single definition) for fast local time/date answers.
        _d("assistant/time-date", "Answer time and date locally", "green", "local_skill"),
    ]

    # -- Skill system ------------------------------------------------------
    defs += [
        _d("skills/jarvis-learn-skill", "Stage reusable skills from workflows", "green", "brain_service"),
        _d("skills/jarvis-search-skills", "Search installed skills", "green", "brain_service"),
        _d("skills/jarvis-run-skill", "Run an installed skill safely", "yellow", "brain_service"),
        _d("skills/jarvis-approve-skill", "Approve staged skill changes", "yellow", "brain_service"),
        _d("skills/jarvis-reject-skill", "Reject staged skill changes", "green", "brain_service"),
        _d("skills/jarvis-diff-skill", "Show pending skill diff", "green", "brain_service"),
        _d("skills/jarvis-delete-skill", "Stage deletion of a skill", "yellow", "brain_service"),
        _d("skills/jarvis-create-bundle", "Create a skill bundle", "yellow", "brain_service"),
        _d("skills/jarvis-run-bundle", "Run a group of skills together", "yellow", "brain_service"),
    ]

    # -- Calendar (Atoll / Apple bridge) -----------------------------------
    defs += [
        _d("calendar/calendar-today", "Show today's calendar", "green", "atoll_apple_bridge"),
        _d("calendar/calendar-tomorrow", "Show tomorrow's calendar", "green", "atoll_apple_bridge"),
        _d("calendar/calendar-week", "Summarize calendar week", "green", "atoll_apple_bridge"),
        _d("calendar/calendar-find-free-time", "Find open calendar slots", "green", "atoll_apple_bridge"),
        _d("calendar/calendar-create-event", "Create calendar event after confirmation", "yellow", "atoll_apple_bridge"),
        _d("calendar/calendar-update-event", "Update calendar event after confirmation", "yellow", "atoll_apple_bridge"),
        _d("calendar/calendar-delete-event", "Delete calendar event after confirmation", "red", "atoll_apple_bridge"),
        _d("calendar/calendar-add-attendee", "Add attendee to calendar event", "yellow", "atoll_apple_bridge"),
        _d("calendar/calendar-respond-invite", "Respond to calendar invite", "yellow", "atoll_apple_bridge"),
        _d("calendar/calendar-daily-brief-source", "Feed calendar into daily brief", "green", "atoll_apple_bridge"),
    ]

    # -- Reminders (Atoll / Apple bridge) ----------------------------------
    defs += [
        _d("reminders/reminder-list", "List reminders", "green", "atoll_apple_bridge"),
        _d("reminders/reminder-create", "Create reminder after confirmation", "yellow", "atoll_apple_bridge"),
        _d("reminders/reminder-complete", "Mark reminder complete", "yellow", "atoll_apple_bridge"),
        _d("reminders/reminder-update", "Update reminder", "yellow", "atoll_apple_bridge"),
        _d("reminders/reminder-delete", "Delete reminder after confirmation", "red", "atoll_apple_bridge"),
        _d("reminders/reminder-today", "Show today's reminders", "green", "atoll_apple_bridge"),
        _d("reminders/reminder-overdue", "Show overdue reminders", "green", "atoll_apple_bridge"),
    ]

    # -- Clock / timers / alarms (Atoll Clock beta) ------------------------
    defs += [
        _d("clock/timer-start", "Start timer", "yellow", "atoll_apple_bridge"),
        _d("clock/timer-list", "List active timers", "green", "atoll_apple_bridge"),
        _d("clock/timer-pause", "Pause timer", "yellow", "atoll_apple_bridge"),
        _d("clock/timer-resume", "Resume timer", "yellow", "atoll_apple_bridge"),
        _d("clock/timer-cancel", "Cancel timer", "yellow", "atoll_apple_bridge"),
        _d("clock/alarm-create", "Create alarm", "yellow", "atoll_apple_bridge"),
        _d("clock/alarm-list", "List alarms", "green", "atoll_apple_bridge"),
        _d("clock/alarm-toggle", "Toggle alarm", "yellow", "atoll_apple_bridge"),
        _d("clock/alarm-delete", "Delete alarm", "red", "atoll_apple_bridge"),
        _d("clock/world-clock", "Give time in another city", "green", "local_skill"),
    ]

    # -- Messages / iMessage ----------------------------------------------
    defs += [
        _d("messages/message-read-visible-thread", "Read visible/current message context only", "green", "brain_service"),
        _d("messages/message-draft-reply", "Draft reply from visible context", "yellow", "brain_service"),
        _d("messages/message-send-confirmed", "Send message after explicit confirmation", "red", "atoll_apple_bridge"),
        _d("messages/message-new-draft", "Draft new message to contact", "yellow", "brain_service"),
        _d("messages/message-search-contact", "Find contact to message", "green", "atoll_apple_bridge"),
        _d("messages/message-summarize-thread", "Summarize visible message thread", "green", "brain_service"),
        _d("messages/message-format-casual", "Format text as casual message", "green", "brain_service"),
    ]

    # -- Email -------------------------------------------------------------
    defs += [
        _d("email/email-search", "Search connected email", "green", "connector", required_connectors=["email"]),
        _d("email/email-read-thread", "Read email thread", "green", "connector", required_connectors=["email"]),
        _d("email/email-summarize-thread", "Summarize email thread", "green", "connector", required_connectors=["email"]),
        _d("email/email-draft-reply", "Draft email reply", "yellow", "brain_service"),
        _d("email/email-new-draft", "Draft new email", "yellow", "brain_service"),
        _d("email/email-send-confirmed", "Send email after explicit confirmation", "red", "connector", required_connectors=["email"]),
        _d("email/email-archive", "Archive email", "yellow", "connector", required_connectors=["email"]),
        _d("email/email-delete", "Delete email", "red", "connector", required_connectors=["email"]),
        _d("email/email-label", "Apply email label", "yellow", "connector", required_connectors=["email"]),
        _d("email/email-find-attachments", "Find email attachments", "green", "connector", required_connectors=["email"]),
        _d("email/email-summarize-attachments", "Summarize email attachments", "green", "connector", required_connectors=["email"]),
    ]

    # -- Contacts / phone / FaceTime --------------------------------------
    defs += [
        _d("contacts/contact-search", "Search saved contacts", "green", "atoll_apple_bridge"),
        _d("contacts/contact-show-card", "Show contact details", "green", "atoll_apple_bridge"),
        _d("phone/call-contact", "Call contact after explicit confirmation", "red", "atoll_apple_bridge"),
        _d("phone/facetime-contact", "FaceTime contact after confirmation", "red", "atoll_apple_bridge"),
        _d("phone/call-number", "Call phone number after confirmation", "red", "atoll_apple_bridge"),
        _d("phone/copy-phone-number", "Copy contact phone number", "green", "atoll_apple_bridge"),
    ]

    # -- Browser -----------------------------------------------------------
    defs += [
        _d("browser/browser-summarize-page", "Summarize current page", "green", "brain_service"),
        _d("browser/browser-explain-page", "Explain current page", "green", "brain_service"),
        _d("browser/browser-extract-action-items", "Extract todos, dates, and links", "green", "brain_service"),
        _d("browser/browser-open-url", "Open website after confirmation", "yellow", "swift_action", executor="open_url"),
        _d("browser/browser-search-web", "Search web if enabled", "green", "web"),
        _d("browser/browser-open-search-results", "Open selected search results", "yellow", "swift_action", executor="open_url"),
        _d("browser/browser-compare-tabs", "Compare captured browser tabs", "green", "brain_service"),
        _d("browser/browser-save-page-to-workspace", "Save page summary to workspace", "yellow", "brain_service"),
        _d("browser/browser-current-url", "Read current browser URL", "green", "swift_action", executor="browser_current_url"),
        _d("browser/browser-copy-url", "Copy current browser URL", "green", "swift_action", executor="copy_to_clipboard"),
        _d("browser/browser-bookmark-page", "Bookmark current page", "yellow", "swift_action", executor="browser_bookmark"),
        _d("browser/browser-open-bookmarks", "Open browser bookmarks", "yellow", "swift_action", executor="browser_open_bookmarks"),
        _d("browser/browser-history-search", "Search browser history", "green", "swift_action", executor="browser_history"),
        _d("browser/browser-downloads-list", "List recent browser downloads", "green", "file_index"),
        _d("browser/browser-fill-form-confirmed", "Fill web form after confirmation", "red", "swift_action", executor="browser_fill_form"),
    ]

    # -- macOS / app control ----------------------------------------------
    defs += [
        _d("macos/mac-open-app", "Open macOS app", "green", "swift_action", executor="open_app"),
        _d("macos/mac-close-app", "Quit macOS app", "yellow", "swift_action", executor="close_app"),
        _d("macos/mac-focus-app", "Bring app forward", "green", "swift_action", executor="focus_app"),
        _d("macos/mac-open-file", "Open approved file", "yellow", "swift_action", executor="open_file"),
        _d("macos/mac-open-folder", "Open folder", "yellow", "swift_action", executor="open_folder"),
        _d("macos/mac-take-screenshot", "Take screenshot", "yellow", "swift_action", executor="take_screenshot"),
        _d("macos/mac-copy-to-clipboard", "Copy text to clipboard", "green", "swift_action", executor="copy_to_clipboard"),
        _d("macos/mac-paste-text", "Paste text into active field", "yellow", "swift_action", executor="paste_text"),
        _d("macos/mac-system-status", "Show system and brain status", "green", "local_skill"),
        _d("macos/mac-sleep", "Put Mac to sleep", "red", "swift_action", executor="sleep_mac"),
        _d("macos/mac-restart", "Restart Mac", "red", "swift_action", executor="restart_mac"),
        _d("macos/mac-shutdown", "Shut down Mac", "red", "swift_action", executor="shutdown_mac"),
    ]

    # -- Media (system playback, separate from Spotify) --------------------
    defs += [
        _d("media/media-play-pause", "Toggle current media playback", "green", "swift_action", executor="media_play_pause"),
        _d("media/media-play", "Resume current media", "green", "swift_action", executor="media_play"),
        _d("media/media-pause", "Pause current media", "green", "swift_action", executor="media_pause"),
        _d("media/media-next-track", "Skip to next track", "green", "swift_action", executor="media_next"),
        _d("media/media-previous-track", "Go to previous track", "green", "swift_action", executor="media_previous"),
        _d("media/media-volume-set", "Set system/media volume", "yellow", "swift_action", executor="volume_set"),
        _d("media/media-volume-up", "Raise volume slightly", "green", "swift_action", executor="volume_up"),
        _d("media/media-volume-down", "Lower volume slightly", "green", "swift_action", executor="volume_down"),
        _d("media/media-now-playing", "Show current media", "green", "swift_action", executor="now_playing"),
        _d("media/media-open-player", "Open active media player", "green", "swift_action", executor="open_player"),
    ]

    # -- Spotify (OAuth + Web API) ----------------------------------------
    defs += [
        _d("spotify/spotify-status", "Check Spotify connection and playback", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-search", "Search Spotify", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-play-track", "Play Spotify track", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-play-artist", "Play Spotify artist", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-play-album", "Play Spotify album", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-play-playlist", "Play Spotify playlist", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-play-liked-songs", "Play liked songs", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-create-playlist", "Create Spotify playlist", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-add-to-playlist", "Add track to playlist", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-save-track", "Save track to library", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-transfer-playback", "Transfer playback device", "yellow", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-shuffle-toggle", "Toggle shuffle", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-repeat-toggle", "Toggle repeat", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-recommend-music", "Recommend music", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
        _d("spotify/spotify-connect-device-list", "List Spotify devices", "green", "spotify_api", required_secrets=SPOTIFY_SECRETS),
    ]

    # -- Writing / text editing -------------------------------------------
    defs += [
        _d("writing/document-rewrite-selection", "Rewrite selected document text", "green", "brain_service"),
        _d("writing/document-summarize-current", "Summarize selected/current document", "green", "brain_service"),
        _d("writing/text-clean-up", "Fix grammar and punctuation", "green", "brain_service"),
        _d("writing/text-make-shorter", "Shorten text", "green", "brain_service"),
        _d("writing/text-make-warmer", "Make text warmer", "green", "brain_service"),
        _d("writing/text-make-more-professional", "Make text more professional", "green", "brain_service"),
        _d("writing/text-make-more-casual", "Make text more casual", "green", "brain_service"),
        _d("writing/text-format-bullets", "Format text as bullets", "green", "brain_service"),
        _d("writing/text-format-email", "Format rough text as email", "green", "brain_service"),
        _d("writing/text-format-message", "Format rough text as message", "green", "brain_service"),
        _d("writing/text-format-notes", "Format messy text as notes", "green", "brain_service"),
        _d("writing/text-format-table", "Format text as simple table", "green", "brain_service"),
        _d("writing/text-preserve-user-style", "Preserve user's writing style", "green", "memory"),
        _d("writing/text-insert-into-active-field", "Insert polished text into active field", "yellow", "swift_action", executor="paste_text"),
    ]

    # -- Dictation ---------------------------------------------------------
    defs += [
        _d("dictation/dictation-cleanup", "Clean dictated transcript", "green", "brain_service"),
        _d("dictation/dictation-format-for-app", "Format dictation for active app", "green", "brain_service"),
        _d("dictation/dictation-insert-text", "Insert cleaned dictation", "yellow", "swift_action", executor="paste_text"),
        _d("dictation/dictation-email-mode", "Format dictation as email", "green", "brain_service"),
        _d("dictation/dictation-message-mode", "Format dictation as casual message", "green", "brain_service"),
        _d("dictation/dictation-document-mode", "Format dictation as document prose", "green", "brain_service"),
        _d("dictation/dictation-code-mode", "Preserve code symbols and formatting", "yellow", "brain_service"),
        _d("dictation/dictation-fix-self-corrections", "Handle spoken self-corrections", "green", "brain_service"),
        _d("dictation/dictation-convert-spoken-symbols", "Convert spoken symbols", "green", "brain_service"),
        _d("dictation/dictation-replace-selection", "Replace selected text with dictation", "yellow", "swift_action", executor="paste_text"),
    ]

    # -- Files / local documents ------------------------------------------
    defs += [
        _d("files/files-search", "Search approved files", "green", "file_index"),
        _d("files/files-read", "Read approved file", "green", "file_index"),
        _d("files/files-summarize", "Summarize approved file", "green", "file_index"),
        _d("files/files-find-recent", "Find recent files", "green", "file_index"),
        _d("files/files-find-downloads", "Find Downloads files", "green", "file_index"),
        _d("files/files-open-confirmed", "Open file after confirmation", "yellow", "swift_action", executor="open_file"),
        _d("files/files-rename-confirmed", "Rename file after confirmation", "yellow", "swift_action", executor="file_rename"),
        _d("files/files-move-confirmed", "Move file after confirmation", "yellow", "swift_action", executor="file_move"),
        _d("files/files-delete-confirmed", "Delete file after explicit confirmation", "red", "swift_action", executor="file_delete"),
        _d("files/files-save-note", "Save note to approved location", "yellow", "brain_service"),
    ]

    # -- Notes & workspace -------------------------------------------------
    defs += [
        _d("notes/note-create", "Create note", "yellow", "atoll_apple_bridge"),
        _d("notes/note-search", "Search notes", "green", "atoll_apple_bridge"),
        _d("notes/note-summarize", "Summarize note", "green", "brain_service"),
        _d("workspace/workspace-create", "Create project workspace", "yellow", "brain_service"),
        _d("workspace/workspace-save-result", "Save useful output to workspace", "yellow", "brain_service"),
        _d("workspace/workspace-search", "Search workspace", "green", "brain_service"),
        _d("workspace/workspace-summary", "Summarize workspace", "green", "brain_service"),
        _d("workspace/workspace-add-decision", "Save project decision", "yellow", "memory"),
    ]

    # -- Memory ------------------------------------------------------------
    defs += [
        _d("memory/memory-add", "Save explicit memory", "green", "memory"),
        _d("memory/memory-search", "Search memory", "green", "memory"),
        _d("memory/memory-update", "Update memory", "yellow", "memory"),
        _d("memory/memory-delete", "Delete memory", "yellow", "memory"),
        _d("memory/memory-list-project", "List project memories", "green", "memory"),
        _d("memory/memory-save-preference", "Save user preference", "green", "memory"),
        _d("memory/memory-save-person", "Save person/contact context", "yellow", "memory"),
    ]

    # -- Automation / daily brief -----------------------------------------
    defs += [
        _d("automation/daily-brief-preview", "Preview daily brief", "green", "scheduler"),
        _d("automation/daily-brief-enable", "Enable daily brief", "yellow", "scheduler"),
        _d("automation/daily-brief-disable", "Disable daily brief", "green", "scheduler"),
        _d("automation/condition-watch-create", "Create condition watch", "yellow", "scheduler"),
        _d("automation/condition-watch-disable", "Stop condition watch", "green", "scheduler"),
        _d("automation/scheduled-skill-run", "Run skill on schedule", "yellow", "scheduler"),
        _d("automation/follow-up-reminder", "Remind about follow-up", "yellow", "scheduler"),
    ]

    # -- Research / web ----------------------------------------------------
    defs += [
        _d("research/web-search", "Search web", "green", "web"),
        _d("research/web-summarize-results", "Summarize web results", "green", "brain_service"),
        _d("research/deep-research", "Multi-step research", "green", "brain_service"),
        _d("research/compare-sources", "Compare sources", "green", "brain_service"),
        _d("research/cite-sources", "Add citations", "green", "brain_service"),
        _d("research/save-research-to-workspace", "Save research to workspace", "yellow", "brain_service"),
    ]

    # -- Code / developer --------------------------------------------------
    defs += [
        _d("dev/code-explain", "Explain selected code", "green", "brain_service"),
        _d("dev/code-review", "Review code", "green", "brain_service"),
        _d("dev/code-edit-plan", "Plan code changes", "green", "brain_service"),
        _d("dev/github-read-repo", "Read GitHub repo", "green", "connector", required_connectors=["github"]),
        _d("dev/github-open-pr", "Open GitHub PR", "yellow", "connector", required_connectors=["github"]),
        _d("dev/shell-command-plan", "Plan shell command", "yellow", "brain_service"),
        _d("dev/shell-command-run-confirmed", "Run shell after confirmation", "red", "swift_action", executor="shell_command"),
        _d("dev/run-tests-confirmed", "Run tests after confirmation", "yellow", "swift_action", executor="run_tests"),
    ]

    # -- Providers / models ------------------------------------------------
    defs += [
        _d("providers/provider-status", "Show configured providers", "green", "provider"),
        _d("providers/provider-test", "Test API keys", "green", "provider"),
        _d("providers/provider-switch", "Switch provider", "yellow", "provider"),
        _d("providers/provider-benchmark", "Benchmark providers", "green", "provider"),
        _d("providers/nvidia-test-model", "Test NVIDIA endpoint", "green", "provider"),
        _d("providers/nvidia-set-main", "Set NVIDIA as main provider", "yellow", "provider"),
    ]

    # -- TTS / voice -------------------------------------------------------
    defs += [
        _d("tts/tts-speak-response", "Speak response", "green", "tts"),
        _d("tts/tts-stop-speaking", "Stop speech playback", "green", "tts"),
        _d("tts/tts-change-voice", "Change voice", "yellow", "tts"),
        _d("tts/tts-benchmark", "Benchmark TTS engines", "green", "tts"),
        _d("tts/tts-fallback-fast-voice", "Use fast fallback voice", "green", "tts"),
    ]

    # -- Calibre project ---------------------------------------------------
    defs += [
        _d("calibre/calibre-investor-prep", "Prep Calibre investor meeting", "green", "brain_service"),
        _d("calibre/calibre-dealer-outreach", "Draft dealer outreach", "green", "brain_service"),
        _d("calibre/calibre-model-review", "Review financial model", "green", "brain_service"),
        _d("calibre/calibre-pitch-polish", "Polish pitch wording", "green", "brain_service"),
        _d("calibre/calibre-competitor-analysis", "Compare watch marketplaces", "green", "brain_service"),
        _d("calibre/calibre-questions-for-investor", "Make investor questions", "green", "brain_service"),
        _d("calibre/calibre-demo-script", "Create demo script", "green", "brain_service"),
        _d("calibre/calibre-marketplace-copy", "Write Calibre marketplace copy", "green", "brain_service"),
        _d("calibre/calibre-launch-checklist", "Create Calibre launch checklist", "green", "brain_service"),
        _d("calibre/calibre-save-decision", "Save Calibre decision", "yellow", "memory"),
    ]

    # -- Notifications -----------------------------------------------------
    defs += [
        _d("notifications/notification-read", "Read recent notifications", "green", "atoll_apple_bridge"),
        _d("notifications/notification-summarize", "Summarize notifications", "green", "brain_service"),
        _d("notifications/notification-clear-confirmed", "Clear notifications after confirmation", "red", "atoll_apple_bridge"),
        _d("notifications/notification-open-source-app", "Open app behind a notification", "yellow", "swift_action", executor="open_app"),
    ]

    # -- Focus modes -------------------------------------------------------
    defs += [
        _d("focus/focus-status", "Show current Focus status", "green", "swift_action", executor="focus_status"),
        _d("focus/focus-enable", "Enable a Focus mode", "yellow", "swift_action", executor="focus_set"),
        _d("focus/focus-disable", "Disable Focus mode", "yellow", "swift_action", executor="focus_set"),
        _d("focus/focus-set-duration", "Set Focus duration", "yellow", "swift_action", executor="focus_set"),
    ]

    # -- Clipboard ---------------------------------------------------------
    defs += [
        _d("clipboard/clipboard-read", "Read clipboard contents", "green", "swift_action", executor="clipboard_read"),
        _d("clipboard/clipboard-summarize", "Summarize clipboard contents", "green", "brain_service"),
        _d("clipboard/clipboard-rewrite", "Rewrite clipboard text", "green", "brain_service"),
        _d("clipboard/clipboard-copy", "Copy text to clipboard", "green", "swift_action", executor="copy_to_clipboard"),
        _d("clipboard/clipboard-clear-confirmed", "Clear clipboard after confirmation", "red", "swift_action", executor="clipboard_clear"),
    ]

    # -- Windows -----------------------------------------------------------
    defs += [
        _d("windows/window-list", "List open windows", "green", "swift_action", executor="window_list"),
        _d("windows/window-focus", "Focus a window", "yellow", "swift_action", executor="window_focus"),
        _d("windows/window-move", "Move a window", "yellow", "swift_action", executor="window_move"),
        _d("windows/window-resize", "Resize a window", "yellow", "swift_action", executor="window_resize"),
        _d("windows/window-split-left", "Snap window to left half", "yellow", "swift_action", executor="window_split"),
        _d("windows/window-split-right", "Snap window to right half", "yellow", "swift_action", executor="window_split"),
        _d("windows/window-minimize", "Minimize a window", "yellow", "swift_action", executor="window_minimize"),
        _d("windows/window-close-confirmed", "Close window after confirmation", "red", "swift_action", executor="window_close"),
    ]

    # -- System ------------------------------------------------------------
    defs += [
        _d("system/system-volume-up", "Raise system volume", "green", "swift_action", executor="volume_up"),
        _d("system/system-volume-down", "Lower system volume", "green", "swift_action", executor="volume_down"),
        _d("system/system-volume-set", "Set system volume", "yellow", "swift_action", executor="volume_set"),
        _d("system/system-mute-toggle", "Toggle system mute", "green", "swift_action", executor="mute_toggle"),
        _d("system/system-brightness-up", "Raise screen brightness", "green", "swift_action", executor="brightness_up"),
        _d("system/system-brightness-down", "Lower screen brightness", "green", "swift_action", executor="brightness_down"),
        _d("system/system-battery-status", "Show battery status", "green", "local_skill"),
        _d("system/system-wifi-status", "Show Wi-Fi status", "green", "local_skill"),
        _d("system/system-bluetooth-status", "Show Bluetooth status", "green", "local_skill"),
    ]

    # -- Screen ------------------------------------------------------------
    defs += [
        _d("screen/screen-read-visible-text", "Read visible on-screen text", "green", "brain_service"),
        _d("screen/screen-ocr", "OCR text from the screen", "green", "swift_action", executor="screen_ocr"),
        _d("screen/screen-explain", "Explain what's on screen", "green", "brain_service"),
        _d("screen/screen-find-text", "Find text on screen", "green", "swift_action", executor="screen_ocr"),
        _d("screen/screen-click-target-confirmed", "Click a screen target after confirmation", "red", "swift_action", executor="screen_click"),
        _d("screen/screen-record-confirmed", "Record the screen after confirmation", "red", "swift_action", executor="screen_record"),
    ]

    # -- Meetings ----------------------------------------------------------
    defs += [
        _d("meetings/meeting-join", "Join the next meeting", "yellow", "swift_action", executor="open_url"),
        _d("meetings/meeting-summarize-notes", "Summarize meeting notes", "green", "brain_service"),
        _d("meetings/meeting-create-notes", "Create meeting notes", "yellow", "brain_service"),
        _d("meetings/meeting-action-items", "Extract meeting action items", "green", "brain_service"),
        _d("meetings/zoom-join", "Join a Zoom meeting", "yellow", "swift_action", executor="open_url"),
        _d("meetings/google-meet-join", "Join a Google Meet", "yellow", "swift_action", executor="open_url"),
    ]

    # -- Apps (GUI automation) --------------------------------------------
    defs += [
        _d("apps/app-menu-action-confirmed", "Trigger an app menu action after confirmation", "red", "swift_action", executor="ui_menu_action"),
        _d("apps/app-keyboard-shortcut-confirmed", "Send a keyboard shortcut after confirmation", "red", "swift_action", executor="ui_keystroke"),
        _d("apps/app-fill-visible-field-confirmed", "Fill a visible field after confirmation", "red", "swift_action", executor="ui_fill_field"),
        _d("apps/app-click-button-confirmed", "Click a button after confirmation", "red", "swift_action", executor="ui_click"),
    ]

    # -- Slack -------------------------------------------------------------
    defs += [
        _d("slack/slack-read-channel", "Read a Slack channel", "green", "connector", required_connectors=["slack"]),
        _d("slack/slack-summarize-channel", "Summarize a Slack channel", "green", "connector", required_connectors=["slack"]),
        _d("slack/slack-draft-reply", "Draft a Slack reply", "yellow", "brain_service"),
        _d("slack/slack-send-confirmed", "Send Slack message after confirmation", "red", "connector", required_connectors=["slack"]),
    ]

    # -- WhatsApp ----------------------------------------------------------
    defs += [
        _d("whatsapp/whatsapp-read-visible-thread", "Read visible WhatsApp thread only", "green", "brain_service"),
        _d("whatsapp/whatsapp-draft-reply", "Draft a WhatsApp reply", "yellow", "brain_service"),
        _d("whatsapp/whatsapp-send-confirmed", "Send WhatsApp message after confirmation", "red", "connector", required_connectors=["whatsapp"]),
    ]

    # -- Maps --------------------------------------------------------------
    defs += [
        _d("maps/maps-search-place", "Search for a place", "green", "web"),
        _d("maps/maps-open-directions", "Open directions to a place", "yellow", "swift_action", executor="open_url"),
        _d("maps/maps-estimate-travel-time", "Estimate travel time", "green", "web"),
    ]

    # -- Weather -----------------------------------------------------------
    defs += [
        _d("weather/weather-current", "Show current weather", "green", "web"),
        _d("weather/weather-forecast", "Show weather forecast", "green", "web"),
        _d("weather/weather-alerts", "Show weather alerts", "green", "web"),
    ]

    # -- Photos ------------------------------------------------------------
    defs += [
        _d("photos/photos-search", "Search Photos library", "green", "swift_action", executor="photos_search"),
        _d("photos/photos-summarize-selection", "Summarize selected photos", "green", "brain_service"),
        _d("photos/photos-open-recent", "Open recent photos", "yellow", "swift_action", executor="open_app"),
        _d("photos/photos-export-confirmed", "Export photos after confirmation", "red", "swift_action", executor="photos_export"),
    ]

    # -- PDF ---------------------------------------------------------------
    defs += [
        _d("pdf/pdf-summarize", "Summarize a PDF", "green", "brain_service"),
        _d("pdf/pdf-extract-text", "Extract text from a PDF", "green", "file_index"),
        _d("pdf/pdf-answer-question", "Answer questions about a PDF", "green", "brain_service"),
        _d("pdf/pdf-find", "Find text in a PDF", "green", "file_index"),
        _d("pdf/pdf-combine-confirmed", "Combine PDFs after confirmation", "red", "swift_action", executor="pdf_combine"),
        _d("pdf/pdf-split-confirmed", "Split a PDF after confirmation", "red", "swift_action", executor="pdf_split"),
    ]

    # -- Spreadsheets ------------------------------------------------------
    defs += [
        _d("spreadsheets/spreadsheet-summarize", "Summarize a spreadsheet", "green", "brain_service"),
        _d("spreadsheets/spreadsheet-clean-data", "Clean spreadsheet data", "yellow", "brain_service"),
        _d("spreadsheets/spreadsheet-create-chart", "Create a chart from data", "yellow", "brain_service"),
        _d("spreadsheets/spreadsheet-explain-formula", "Explain a spreadsheet formula", "green", "brain_service"),
        _d("spreadsheets/spreadsheet-fix-formula", "Fix a spreadsheet formula", "green", "brain_service"),
    ]

    # -- Presentations -----------------------------------------------------
    defs += [
        _d("presentations/presentation-summarize", "Summarize a presentation", "green", "brain_service"),
        _d("presentations/presentation-outline", "Outline a presentation", "green", "brain_service"),
        _d("presentations/presentation-speaker-notes", "Write speaker notes", "green", "brain_service"),
        _d("presentations/presentation-polish-slide-text", "Polish slide text", "green", "brain_service"),
    ]

    # -- Security ----------------------------------------------------------
    defs += [
        _d("security/security-explain-permissions", "Explain granted permissions", "green", "brain_service"),
        _d("security/security-show-data-access", "Show what data Jarvis can access", "green", "brain_service"),
        _d("security/security-revoke-connector", "Revoke a connector after confirmation", "red", "connector"),
        _d("security/security-clear-history-confirmed", "Clear history after confirmation", "red", "memory"),
        _d("security/security-export-data-confirmed", "Export data after confirmation", "red", "brain_service"),
    ]

    # -- Shopping ----------------------------------------------------------
    defs += [
        _d("shopping/shopping-compare-products", "Compare products", "green", "web"),
        _d("shopping/shopping-track-price", "Track a product price", "yellow", "scheduler"),
        _d("shopping/shopping-open-product-page", "Open a product page", "yellow", "swift_action", executor="open_url"),
        _d("shopping/shopping-save-research", "Save shopping research", "yellow", "brain_service"),
    ]

    # -- Finance -----------------------------------------------------------
    defs += [
        _d("finance/finance-stock-price", "Show a stock price", "green", "web"),
        _d("finance/finance-portfolio-summary", "Summarize a portfolio", "green", "brain_service"),
        _d("finance/finance-market-news", "Show market news", "green", "web"),
        _d("finance/finance-crypto-price", "Show a crypto price", "green", "web"),
    ]

    # -- Learning ----------------------------------------------------------
    defs += [
        _d("learning/learning-explain-concept", "Explain a concept", "green", "brain_service"),
        _d("learning/learning-make-study-guide", "Make a study guide", "green", "brain_service"),
        _d("learning/learning-quiz-me", "Quiz the user", "green", "brain_service"),
        _d("learning/learning-flashcards", "Make flashcards", "green", "brain_service"),
    ]

    # -- Travel ------------------------------------------------------------
    defs += [
        _d("travel/travel-itinerary-summary", "Summarize a travel itinerary", "green", "brain_service"),
        _d("travel/travel-find-flight-info", "Find flight info", "green", "web"),
        _d("travel/travel-find-hotel-info", "Find hotel info", "green", "web"),
        _d("travel/travel-open-directions", "Open travel directions", "yellow", "swift_action", executor="open_url"),
        _d("travel/travel-pack-list", "Make a packing list", "green", "brain_service"),
    ]

    # -- Health ------------------------------------------------------------
    defs += [
        _d("health/health-log-note", "Log a health note", "yellow", "memory"),
        _d("health/health-medication-reminder", "Set a medication reminder", "yellow", "scheduler"),
        _d("health/health-appointment-prep", "Prep for a health appointment", "green", "brain_service"),
    ]

    # -- Personal ----------------------------------------------------------
    defs += [
        _d("personal/personal-decision-log", "Log a personal decision", "yellow", "memory"),
        _d("personal/personal-brain-dump-cleanup", "Clean up a brain dump", "green", "brain_service"),
        _d("personal/personal-plan-day", "Plan the day", "green", "brain_service"),
        _d("personal/personal-prioritize-tasks", "Prioritize tasks", "green", "brain_service"),
    ]

    return defs


# Built once at import. Single source of truth for the whole catalog.
CATALOG: List[SkillDef] = _catalog()
