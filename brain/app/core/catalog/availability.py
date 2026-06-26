from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, Optional, Set, Tuple

from .models import SkillDef

# Folder category -> Atoll/Apple bridge area used for availability.
_CATEGORY_TO_ATOLL_AREA = {
    "calendar": "calendar",
    "reminders": "reminders",
    "clock": "clock",
    "contacts": "contacts",
    "phone": "phone",
    "messages": "messages",
    "notes": "notes",
    "notifications": "notifications",
}

# Swift actions the Mac app actually consumes today. Anything else is honestly
# reported as not-yet-wired. Override with JARVIS_WIRED_SWIFT_ACTIONS (comma
# list, or "*" to declare full support from the Swift side).
_DEFAULT_WIRED_SWIFT_ACTIONS = {"open_app", "open_url", "focus_app", "copy_to_clipboard"}


def wired_swift_actions() -> Set[str]:
    raw = os.environ.get("JARVIS_WIRED_SWIFT_ACTIONS", "").strip()
    if not raw:
        return set(_DEFAULT_WIRED_SWIFT_ACTIONS)
    if raw == "*":
        return {"*"}
    return {item.strip() for item in raw.split(",") if item.strip()}


@dataclass
class AvailabilityContext:
    """Snapshot of live executor/connector/service states used to decide
    whether each catalog capability is actually available right now."""

    providers_available: bool = False
    file_index_enabled: bool = False
    file_count: int = 0
    web_available: bool = False
    memory_available: bool = False
    tts_available: bool = False
    scheduler_available: bool = True
    atoll: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    spotify: Dict[str, Any] = field(default_factory=dict)
    enabled_connectors: Set[str] = field(default_factory=set)
    wired_actions: Set[str] = field(default_factory=wired_swift_actions)

    # -- named executor helpers (per spec) --------------------------------
    def atoll_area_available(self, area: str, *, write: bool = False) -> bool:
        info = self.atoll.get(area) or {}
        if not info.get("available"):
            return False
        return bool(info.get("write")) if write else bool(info.get("read"))

    def atoll_calendar_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("calendar", write=write)

    def atoll_reminders_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("reminders", write=write)

    def atoll_clock_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("clock", write=write)

    def atoll_messages_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("messages", write=write)

    def atoll_contacts_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("contacts", write=write)

    def atoll_phone_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("phone", write=write)

    def atoll_notes_available(self, *, write: bool = False) -> bool:
        return self.atoll_area_available("notes", write=write)

    def spotify_available(self) -> bool:
        return bool(self.spotify.get("connected"))

    def swift_action_available(self, action_type: str) -> bool:
        if "*" in self.wired_actions:
            return True
        return action_type in self.wired_actions

    def email_connector_available(self) -> bool:
        return "email" in self.enabled_connectors or "gmail" in self.enabled_connectors

    def file_index_available(self) -> bool:
        return self.file_index_enabled

    def provider_available(self) -> bool:
        return self.providers_available


def resolve_availability(defn: SkillDef, ctx: AvailabilityContext) -> Tuple[bool, str]:
    """Return (available, status_reason) for a catalog skill given live state."""
    source = defn.source

    if source in ("brain_service", "local_skill"):
        return True, ""

    if source == "memory":
        return (True, "") if ctx.memory_available else (False, "memory service is unavailable")

    if source == "tts":
        return (True, "") if ctx.tts_available else (False, "no TTS engine is available")

    if source == "web":
        return (True, "") if ctx.web_available else (False, "web search is disabled in Settings")

    if source == "provider":
        return (True, "") if ctx.providers_available else (False, "no model provider API key is configured")

    if source == "scheduler":
        return (True, "") if ctx.scheduler_available else (False, "scheduled agents are unavailable")

    if source == "file_index":
        if not ctx.file_index_enabled:
            return False, "file index is off; enable it and approve folders in Context settings"
        return True, ""

    if source == "connector":
        missing = [c for c in defn.required_connectors if c not in ctx.enabled_connectors]
        if missing:
            label = ", ".join(missing)
            return False, f"{label} connector is not connected"
        return True, ""

    if source == "swift_action":
        action = defn.executor or defn.name
        if ctx.swift_action_available(action):
            return True, ""
        return False, f"Swift '{action}' executor is not wired yet"

    if source == "atoll_apple_bridge":
        area = _CATEGORY_TO_ATOLL_AREA.get(defn.category, defn.category)
        need_write = defn.risk_level in {"yellow", "red"}
        info = ctx.atoll.get(area) or {}
        if not info.get("available"):
            reason = info.get("reason") or f"Atoll {area} bridge is not connected yet"
            return False, reason
        if need_write and not info.get("write"):
            return False, f"Atoll {area} bridge is read-only; write access is not enabled"
        if not need_write and not info.get("read"):
            return False, f"Atoll {area} bridge cannot read yet"
        return True, ""

    if source == "spotify_api":
        if ctx.spotify.get("connected"):
            return True, ""
        reason = ctx.spotify.get("reason") or "Spotify is not connected; add Spotify OAuth credentials in Settings"
        return False, reason

    # Unknown source: fail closed but explain.
    return False, f"source '{source}' has no availability resolver"


def build_context(
    *,
    providers: Optional[Any] = None,
    file_index: Optional[Any] = None,
    web: Optional[Any] = None,
    memory: Optional[Any] = None,
    tts: Optional[Any] = None,
    scheduler: Optional[Any] = None,
    atoll: Optional[Any] = None,
    spotify: Optional[Any] = None,
    enabled_connectors: Optional[Set[str]] = None,
) -> AvailabilityContext:
    ctx = AvailabilityContext()
    ctx.enabled_connectors = {str(c).lower() for c in (enabled_connectors or set())}

    try:
        ctx.providers_available = bool(providers and providers.enabled_chain())
    except Exception:
        ctx.providers_available = False

    try:
        status = file_index.status() if file_index else {}
        ctx.file_index_enabled = str(status.get("indexingMode") or "off") != "off"
        ctx.file_count = int(status.get("fileCount") or 0)
    except Exception:
        ctx.file_index_enabled = False

    try:
        ctx.web_available = bool(web) and str(getattr(web, "mode", "disabled")) != "disabled"
    except Exception:
        ctx.web_available = False

    ctx.memory_available = memory is not None
    ctx.tts_available = tts is not None
    ctx.scheduler_available = True if scheduler is None else True

    ctx.atoll = atoll.status() if atoll is not None else _default_atoll_status()
    ctx.spotify = spotify.status() if spotify is not None else {"configured": False, "connected": False}
    ctx.wired_actions = wired_swift_actions()
    return ctx


def _default_atoll_status() -> Dict[str, Dict[str, Any]]:
    areas = ["calendar", "reminders", "clock", "contacts", "phone", "messages", "notes", "notifications"]
    return {area: {"available": False, "read": False, "write": False, "reason": f"Atoll {area} bridge is not connected yet"} for area in areas}
