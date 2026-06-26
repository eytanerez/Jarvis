from __future__ import annotations

import os
from typing import Any, Dict, Iterable, Optional

from .capability import Capability


class CapabilityLoader:
    """Builds runtime capability records from actual brain services/context."""

    def __init__(
        self,
        providers: Optional[Any] = None,
        memory: Optional[Any] = None,
        file_index: Optional[Any] = None,
        web: Optional[Any] = None,
        skill_manager: Optional[Any] = None,
        dictation: Optional[Any] = None,
        tts: Optional[Any] = None,
        atoll: Optional[Any] = None,
        spotify: Optional[Any] = None,
        scheduler: Optional[Any] = None,
    ) -> None:
        self.providers = providers
        self.memory = memory
        self.file_index = file_index
        self.web = web
        self.skill_manager = skill_manager
        self.dictation = dictation
        self.tts = tts
        self.atoll = atoll
        self.spotify = spotify
        self.scheduler = scheduler

    def load(
        self,
        mode: str = "quick_assistant",
        situation: Optional[Any] = None,
        enabled_connectors: Optional[Iterable[str]] = None,
        available_permissions: Optional[Iterable[str]] = None,
        installed_skills: Optional[list[dict]] = None,
        active_context: Optional[Dict[str, Any]] = None,
    ) -> list[Capability]:
        connectors = {str(item).lower() for item in enabled_connectors or []}
        permissions = {str(item).lower() for item in available_permissions or []}
        context = active_context or {}
        context_flags = self._context_flags(context)
        provider_chain = self._safe_provider_chain()
        file_status = self._safe_file_status()
        web_mode = self._safe_web_mode()
        skills = installed_skills if installed_skills is not None else self._safe_installed_skills()

        file_mode = str(file_status.get("indexingMode") or "off")
        file_enabled = file_mode != "off"
        file_count = int(file_status.get("fileCount") or 0)
        live_web_available = web_mode not in {"disabled", "real_provider"}
        real_web_configured = web_mode not in {"disabled", "demo", "real_provider"}
        current_schedule = bool(context.get("schedule"))
        calendar_available = current_schedule or "calendar" in connectors
        reminders_available = current_schedule or "reminders" in connectors
        email_connected = "email" in connectors or "gmail" in connectors
        messages_connected = "messages" in connectors or "imessage" in connectors
        whatsapp_connected = "whatsapp" in connectors

        capabilities = [
            self._cap(
                "assistant.answer_general_question",
                "answer general questions",
                "Answer normal questions using the configured model provider.",
                "assistant_core",
                source="model",
                available=bool(provider_chain),
                required_secrets=[] if provider_chain else ["provider_api_key"],
                limitations=[] if provider_chain else ["No model provider API key is configured."],
                status_reason="" if provider_chain else "add a provider API key in Settings",
                examples=["What should I focus on today?", "Explain this error."],
                how_to_use="Ask normally. If no model provider is configured, local deterministic commands still work.",
            ),
            self._cap(
                "assistant.use_current_context",
                "use current Mac context",
                "Use app-provided active app, selected text, browser, document, file, schedule, or accessibility context.",
                "assistant_core",
                source="brain_service",
                available=context_flags["any_text"] or current_schedule,
                required_permissions=["accessibility"],
                status_reason="no current app text or schedule snapshot was provided" if not (context_flags["any_text"] or current_schedule) else "",
                limitations=["Only context sent by the Mac app is visible. Screen/browser text is treated as untrusted reference material."],
                examples=["Summarize this.", "What am I looking at?"],
                how_to_use="Select text or focus the app/page you mean, then ask about it.",
            ),
            self._cap(
                "dictation.clean_and_insert_text",
                "clean and insert dictation",
                "Clean dictated text, format it for the active app, and ask Swift to insert it.",
                "dictation",
                source="brain_service",
                available=self.dictation is not None,
                required_permissions=["microphone", "accessibility"],
                examples=["Clean this dictation.", "Dictate into Mail."],
                how_to_use="Use the configured dictation hotkey, then review or insert the cleaned result.",
            ),
            self._cap(
                "document.rewrite_selected_text",
                "rewrite selected text",
                "Rewrite selected or current document text from provided context.",
                "documents",
                source="brain_service",
                available=context_flags["selected_text"] or context_flags["document_text"],
                required_permissions=["accessibility"],
                status_reason="select text or provide document context first" if not (context_flags["selected_text"] or context_flags["document_text"]) else "",
                examples=["Rewrite this more directly.", "Make this paragraph warmer."],
                how_to_use="Select the text in the current app or document, then ask for the rewrite.",
            ),
            self._cap(
                "document.summarize_current_document",
                "summarize current document",
                "Summarize selected, current, or preview document text from provided context.",
                "documents",
                source="brain_service",
                available=context_flags["document_text"] or context_flags["selected_text"],
                required_permissions=["accessibility"],
                status_reason="document text is unavailable until the app provides it" if not (context_flags["document_text"] or context_flags["selected_text"]) else "",
                examples=["Summarize this document.", "What are the key points here?"],
                how_to_use="Open or select the document content, then ask for a summary.",
            ),
            self._cap(
                "browser.summarize_current_page",
                "summarize current browser page",
                "Summarize browser page text captured by the Mac app.",
                "browser",
                source="brain_service",
                available=context_flags["browser_page"],
                required_permissions=["automation", "accessibility"],
                status_reason="browser page text was not provided" if not context_flags["browser_page"] else "",
                limitations=["Jarvis cannot read a browser page unless the app provides page text for the turn."],
                examples=["Summarize this page.", "What is this article saying?"],
                how_to_use="Focus the browser tab, then ask Jarvis to summarize the page.",
            ),
            self._cap(
                "files.search_approved_index",
                "search approved local files",
                "Search the approved local file index.",
                "files",
                source="brain_service",
                available=file_enabled,
                required_permissions=["file_index"],
                limitations=[f"Index mode is {file_mode}; indexed file count is {file_count}."],
                status_reason="file index is off" if not file_enabled else "",
                examples=["Find the latest contract PDF.", "Search my Downloads from yesterday."],
                how_to_use="Enable the file index and approve folders in Context settings, then ask for files by name or topic.",
            ),
            self._cap(
                "files.summarize_file",
                "summarize approved files",
                "Read and summarize files already inside the approved file index.",
                "files",
                source="brain_service",
                available=file_enabled and file_count > 0,
                required_permissions=["file_index"],
                status_reason="no indexed files are available yet" if file_enabled and file_count == 0 else "file index is off" if not file_enabled else "",
                limitations=["Files must be in approved folders and must not match exclusions."],
                examples=["Summarize this indexed file.", "Read the newest PDF in Downloads."],
                how_to_use="First index approved folders, then ask Jarvis to summarize a specific matching file.",
            ),
            self._cap(
                "memory.remember_explicit_fact",
                "remember explicit facts",
                "Store facts the user explicitly asks Jarvis to remember.",
                "memory",
                source="brain_service",
                available=self.memory is not None,
                examples=["Remember that the launch name is Calibre.", "Don't forget that I prefer concise drafts."],
                how_to_use="Start with 'remember that' or 'don't forget'. Jarvis stores only explicit memory requests.",
            ),
            self._cap(
                "memory.search_user_memory",
                "search user memory",
                "Search saved user memories and profile memory.",
                "memory",
                source="brain_service",
                available=self.memory is not None,
                examples=["What do you remember about the Calibre launch?", "What do you know about me?"],
                how_to_use="Ask what Jarvis remembers, or ask a question that benefits from saved preferences.",
            ),
            self._cap(
                "email.search",
                "search email",
                "Search connected email accounts.",
                "email",
                source="connector",
                available=email_connected,
                required_connectors=["email"],
                status_reason="email connector is not connected" if not email_connected else "",
                limitations=["The current brain has only email scaffolding unless a connector is enabled."],
                examples=["Find the latest email from Sam."],
                how_to_use="Connect an email connector before asking Jarvis to search mail.",
            ),
            self._cap(
                "email.draft_reply",
                "draft email replies",
                "Draft a reply from provided email or selected text context.",
                "email",
                source="brain_service",
                available=context_flags["any_text"] or email_connected,
                required_connectors=[] if context_flags["any_text"] else ["email"],
                requires_confirmation=True,
                risk_level="yellow",
                status_reason="provide visible email text or connect email" if not (context_flags["any_text"] or email_connected) else "",
                examples=["Draft a reply to this email.", "Make this email more concise."],
                how_to_use="Open or select the email text. Jarvis can draft, but sending requires confirmation.",
            ),
            self._cap(
                "email.send_confirmed",
                "send confirmed email",
                "Send email only after explicit user confirmation.",
                "email",
                source="connector",
                available=email_connected,
                required_connectors=["email"],
                requires_confirmation=True,
                risk_level="red",
                status_reason="email connector is not connected" if not email_connected else "",
                examples=["Send this after I approve."],
                how_to_use="Connect email first. Jarvis must show the draft and receive confirmation before sending.",
            ),
            self._cap(
                "messages.draft_reply",
                "draft message replies",
                "Draft a message reply from visible or selected conversation context.",
                "messages",
                source="brain_service",
                available=context_flags["any_text"] or messages_connected or whatsapp_connected,
                required_connectors=[] if context_flags["any_text"] else ["messages"],
                requires_confirmation=True,
                risk_level="yellow",
                status_reason="provide visible message text or connect a messages connector" if not (context_flags["any_text"] or messages_connected or whatsapp_connected) else "",
                examples=["Draft a reply to this message."],
                how_to_use="Open or select the message text. Jarvis can draft, but sending requires confirmation.",
            ),
            self._cap(
                "messages.send_confirmed",
                "send confirmed messages",
                "Send messages only after explicit confirmation through a connected connector.",
                "messages",
                source="connector",
                available=messages_connected,
                required_connectors=["messages"],
                requires_confirmation=True,
                risk_level="red",
                status_reason="messages connector is not connected" if not messages_connected else "",
                limitations=["WhatsApp full history is unavailable unless a supported connector provides it."],
                examples=["Send this text after I confirm."],
                how_to_use="Connect a supported messages connector and confirm the final send action.",
            ),
            self._cap(
                "calendar.today",
                "read today's calendar",
                "Use the current local schedule snapshot when the app provides it.",
                "calendar",
                source="brain_service",
                available=calendar_available,
                required_permissions=["calendar"],
                status_reason="calendar snapshot or connector is unavailable" if not calendar_available else "",
                examples=["What's on my calendar today?", "Do I have anything after lunch?"],
                how_to_use="Grant calendar access in the Mac app so Jarvis can receive a schedule snapshot.",
            ),
            self._cap(
                "calendar.find_free_time",
                "find free calendar time",
                "Reason over the current schedule snapshot to find open time.",
                "calendar",
                source="brain_service",
                available=calendar_available,
                required_permissions=["calendar"],
                status_reason="calendar snapshot or connector is unavailable" if not calendar_available else "",
                examples=["Find me 30 minutes this afternoon."],
                how_to_use="Provide or refresh the local schedule snapshot, then ask for open slots.",
            ),
            self._cap(
                "reminders.create",
                "create reminders",
                "Create reminders through the Mac side only when a supported action exists and is confirmed.",
                "reminders",
                source="swift_action",
                available=False,
                required_permissions=["reminders"],
                requires_confirmation=True,
                risk_level="yellow",
                status_reason="the brain has reminder snapshots, but no create-reminder executor is wired yet",
                examples=["Remind me to send the deck tomorrow."],
                how_to_use="Jarvis can discuss reminders from snapshots now. Creating reminders needs a Mac executor before it is advertised as available.",
            ),
            self._cap(
                "mac.open_app",
                "open apps",
                "Ask Swift to open an installed macOS application.",
                "mac_actions",
                source="swift_action",
                available=True,
                required_permissions=["automation"],
                examples=["Open Safari.", "Launch Spotify."],
                how_to_use="Ask Jarvis to open or launch an app by name.",
            ),
            self._cap(
                "mac.open_url",
                "open URLs",
                "Ask Swift to open a URL or search shortcut.",
                "mac_actions",
                source="swift_action",
                available=True,
                required_permissions=["automation"],
                requires_confirmation=True,
                risk_level="yellow",
                examples=["Open example.com.", "Visit the GitHub repo."],
                how_to_use="Ask Jarvis to open a specific site. Jarvis should ask before opening external URLs.",
            ),
            self._cap(
                "mac.take_screenshot",
                "take screenshots",
                "Capture the current screen through a Mac action.",
                "mac_actions",
                source="swift_action",
                available=False,
                required_permissions=["screen_recording"],
                requires_confirmation=True,
                risk_level="yellow",
                status_reason="screenshot action is planned in the brain but not executed by the current Swift action executor",
                examples=["Take a screenshot."],
                how_to_use="Enable a Swift screenshot executor before Jarvis advertises this as available.",
            ),
            self._cap(
                "web.search",
                "web search",
                "Return web/search shortcuts or live results depending on configured web mode.",
                "web",
                source="brain_service",
                available=live_web_available or real_web_configured,
                limitations=[self._web_limitation(web_mode)],
                status_reason="web search is disabled" if web_mode == "disabled" else "real web provider is not configured" if web_mode == "real_provider" else "",
                examples=["Find places to buy an iPad."],
                how_to_use="Set web search mode in provider settings. Demo mode returns search/result shortcuts, not verified live results.",
            ),
            self._cap(
                "tts.speak_response",
                "speak responses",
                "Synthesize spoken responses through configured local TTS.",
                "tts",
                source="brain_service",
                available=self.tts is not None,
                examples=["Read that aloud."],
                how_to_use="Enable voice/TTS settings. The Mac app controls playback.",
            ),
            self._cap(
                "skills.run_skill",
                "run installed skills",
                "Load installed SKILL.md procedures and prepare a safe run.",
                "skills",
                source="local_skill",
                available=bool(skills),
                limitations=[f"{len(skills)} installed skills visible."] if skills is not None else [],
                examples=["Run the dealer outreach skill.", "Do the Calibre launch workflow."],
                how_to_use="Ask for a named skill or workflow. Jarvis loads the skill before using model reasoning when it is a clear match.",
            ),
            self._cap(
                "skills.learn_new_skill",
                "learn new skills",
                "Stage a reusable SKILL.md from an approved workflow.",
                "skills",
                source="brain_service",
                available=self.skill_manager is not None,
                examples=["Learn this.", "Make this a skill.", "Remember how to do this."],
                how_to_use="Say 'learn this' or describe the workflow. Jarvis stages the skill for review before install.",
            ),
            self._cap(
                "skills.approve_skill",
                "approve staged skills",
                "Approve or reject staged skill changes.",
                "skills",
                source="brain_service",
                available=self.skill_manager is not None,
                requires_confirmation=True,
                risk_level="yellow",
                examples=["Approve skill abc123.", "Show pending skills."],
                how_to_use="Use /skills pending, /skills diff <id>, /skills approve <id>, or the Skills settings UI.",
            ),
            self._cap(
                "jarvis.explain_capabilities",
                "explain capabilities",
                "Explain available and unavailable Jarvis features from the live registry.",
                "assistant_core",
                source="brain_service",
                available=True,
                examples=["What can you do?", "Can you read my email?", "What skills do you have?"],
                how_to_use="Ask what Jarvis can do, or ask about a specific feature.",
            ),
            self._cap(
                "settings.manage_prompts",
                "manage prompts and settings",
                "View and save editable prompt/settings sections through the brain routes.",
                "settings",
                source="brain_service",
                available=True,
                examples=["Open prompt settings.", "What prompt sources are active?"],
                how_to_use="Use Settings to edit provider, privacy, context, prompt, skill, and performance sections.",
            ),
            self._cap(
                "automation.daily_brief",
                "scheduled daily brief",
                "Preview or run opt-in scheduled summaries from enabled local sources.",
                "automation",
                source="brain_service",
                available=True,
                requires_confirmation=False,
                limitations=["Only enabled sources with local snapshots are included."],
                examples=["Preview my daily brief."],
                how_to_use="Enable scheduled agents and select sources in Settings.",
            ),
            self._cap(
                "developer.run_confirmed_shell_command",
                "run confirmed shell commands",
                "Run shell commands only through the Mac action executor after explicit approval.",
                "developer",
                source="swift_action",
                available=os.environ.get("JARVIS_ENABLE_SHELL_ACTIONS", "").lower() in {"1", "true", "yes"},
                requires_confirmation=True,
                risk_level="red",
                status_reason="shell actions are disabled by default" if os.environ.get("JARVIS_ENABLE_SHELL_ACTIONS", "").lower() not in {"1", "true", "yes"} else "",
                limitations=["No shell command may run silently. Destructive commands require explicit approval."],
                examples=["Run this command after I confirm."],
                how_to_use="Enable shell actions explicitly and review the command before confirming.",
            ),
        ]
        capabilities.extend(self._catalog_capabilities(connectors))
        seen: set[str] = set()
        deduped = []
        for capability in capabilities:
            if capability.id in seen:
                continue
            seen.add(capability.id)
            deduped.append(capability)
        return [capability for capability in deduped if self._mode_allowed(capability, mode)]

    def _catalog_capabilities(self, connectors: set[str]) -> list[Capability]:
        """Build canonical catalog-derived capabilities from live executor state."""
        try:
            from ..catalog import build_context, catalog_capabilities
        except Exception:
            return []
        try:
            ctx = build_context(
                providers=self.providers,
                file_index=self.file_index,
                web=self.web,
                memory=self.memory,
                tts=self.tts,
                scheduler=self.scheduler,
                atoll=self.atoll,
                spotify=self.spotify,
                enabled_connectors=connectors,
            )
            return catalog_capabilities(ctx)
        except Exception:
            return []

    def _cap(self, *args: Any, **kwargs: Any) -> Capability:
        if "enabled" not in kwargs:
            kwargs["enabled"] = True
        if kwargs.get("enabled") is False:
            kwargs["available"] = False
        return Capability(*args, **kwargs)

    def _safe_provider_chain(self) -> list[str]:
        if self.providers is None:
            return []
        try:
            return list(self.providers.enabled_chain())
        except Exception:
            return []

    def _safe_file_status(self) -> Dict[str, Any]:
        if self.file_index is None:
            return {"indexingMode": "off", "fileCount": 0}
        try:
            return dict(self.file_index.status())
        except Exception:
            return {"indexingMode": "off", "fileCount": 0}

    def _safe_web_mode(self) -> str:
        if self.web is None:
            return "disabled"
        try:
            return str(self.web.mode)
        except Exception:
            return "disabled"

    def _safe_installed_skills(self) -> list[dict]:
        if self.skill_manager is None:
            return []
        try:
            return list(self.skill_manager.list())
        except Exception:
            return []

    def _context_flags(self, context: Dict[str, Any]) -> Dict[str, bool]:
        browser = context.get("browser") or {}
        document = context.get("documentContext") or {}
        accessibility = context.get("accessibility") or {}

        def has(value: Any) -> bool:
            return bool(str(value or "").strip())

        selected = has(context.get("selectedText")) or has(browser.get("selectedText")) or has(document.get("selectedText"))
        document_text = any(
            has(document.get(key))
            for key in ["selectedText", "currentParagraph", "previousParagraph", "nextParagraph", "textPreview"]
        )
        browser_page = has(browser.get("pageText"))
        any_text = (
            selected
            or document_text
            or browser_page
            or has(context.get("surroundingText"))
            or has(accessibility.get("visibleText"))
            or bool(context.get("relevantFiles"))
            or bool(context.get("relevantMemories"))
        )
        return {
            "selected_text": selected,
            "document_text": document_text,
            "browser_page": browser_page,
            "any_text": any_text,
        }

    def _mode_allowed(self, capability: Capability, mode: str) -> bool:
        return "*" in capability.allowed_modes or mode in capability.allowed_modes

    def _web_limitation(self, mode: str) -> str:
        if mode == "demo":
            return "Web search is in demo mode and returns shortcuts, not verified live results."
        if mode == "real_provider":
            return "A real web provider mode is selected, but no real provider is configured yet."
        if mode == "disabled":
            return "Web search is disabled in Settings."
        return f"Web search mode is {mode}."
