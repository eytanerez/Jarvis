from __future__ import annotations

import json
import os
from datetime import datetime, time, timedelta
from pathlib import Path
from typing import Any, Dict, Optional
from zoneinfo import ZoneInfo


class ScheduledAgentService:
    DEFAULT_SOURCES = {
        "calendar": True,
        "reminders": True,
        "email": False,
        "weather": False,
        "news": False,
        "tasks": False,
    }

    def __init__(self, app_support_root: Optional[Path] = None) -> None:
        self.app_support_root = Path(app_support_root or self.default_app_support_root()).expanduser()
        self.root = Path(os.environ.get("JARVIS_SCHEDULED_AGENTS_HOME", self.app_support_root / "scheduled-agents")).expanduser()
        self.root.mkdir(parents=True, exist_ok=True)
        self.config_path = self.root / "agents.json"
        self._ensure_defaults()

    @staticmethod
    def default_app_support_root() -> Path:
        if os.environ.get("JARVIS_APP_SUPPORT_HOME"):
            return Path(os.environ["JARVIS_APP_SUPPORT_HOME"])
        if os.environ.get("JARVIS_BRAIN_HOME"):
            return Path(os.environ["JARVIS_BRAIN_HOME"]) / "app_support"
        return Path.home() / "Library" / "Application Support" / "JarvisNotch"

    def list(self) -> dict:
        agents = self._load()
        return {"agents": [self._with_runtime_fields(agent) for agent in agents.values()]}

    def get(self, agent_id: str) -> dict:
        agents = self._load()
        agent = agents.get(agent_id)
        if agent is None:
            raise KeyError(agent_id)
        return self._with_runtime_fields(agent)

    def update(self, agent_id: str, updates: dict) -> dict:
        agents = self._load()
        agent = agents.get(agent_id)
        if agent is None:
            raise KeyError(agent_id)
        for key in ["enabled", "time", "timezone"]:
            if key in updates:
                agent[key] = updates[key]
        if isinstance(updates.get("sources"), dict):
            sources = dict(agent.get("sources") or self.DEFAULT_SOURCES)
            for key, value in updates["sources"].items():
                if key in self.DEFAULT_SOURCES:
                    sources[key] = bool(value)
            agent["sources"] = sources
        agent["updatedAt"] = datetime.now().astimezone().isoformat()
        agents[agent_id] = agent
        self._save(agents)
        return self._with_runtime_fields(agent)

    def record_run(self, agent_id: str, run_at: Optional[str] = None) -> dict:
        agents = self._load()
        agent = agents.get(agent_id)
        if agent is None:
            raise KeyError(agent_id)
        agent["lastRunAt"] = run_at or datetime.now().astimezone().isoformat()
        agent["updatedAt"] = datetime.now().astimezone().isoformat()
        agents[agent_id] = agent
        self._save(agents)
        return self._with_runtime_fields(agent)

    def preview(self, agent_id: str, payload: Optional[dict] = None) -> dict:
        agent = self.get(agent_id)
        if agent_id != "daily_brief":
            raise KeyError(agent_id)
        payload = payload or {}
        context = payload.get("context") if isinstance(payload.get("context"), dict) else {}
        schedule = payload.get("schedule") if isinstance(payload.get("schedule"), dict) else context.get("schedule", {})
        schedule = schedule if isinstance(schedule, dict) else {}
        sources = dict(agent.get("sources") or {})
        events = schedule.get("events") if sources.get("calendar") else []
        reminders = schedule.get("reminders") if sources.get("reminders") else []
        events = events if isinstance(events, list) else []
        reminders = reminders if isinstance(reminders, list) else []
        source_lines = []
        sources_used = []
        if sources.get("calendar"):
            sources_used.append("calendar")
            source_lines.append(self._calendar_line(events, schedule))
        if sources.get("reminders"):
            sources_used.append("reminders")
            source_lines.append(self._reminders_line(reminders, schedule))
        for source in ["email", "weather", "news", "tasks"]:
            if sources.get(source):
                source_lines.append(f"{source.title()}: connector not enabled yet.")
        if not source_lines:
            source_lines.append("No sources are enabled for this brief.")
        status = "enabled" if agent.get("enabled") else "disabled"
        answer = (
            f"Daily brief preview ({status}, scheduled for {agent.get('time')} {agent.get('timezone')}):\n"
            + "\n".join(f"- {line}" for line in source_lines)
        )
        speak = self._brief_speak(events, reminders, sources)
        return {
            "agent": agent,
            "answer": answer,
            "speak": speak,
            "sourcesUsed": sources_used,
            "metadata": {
                "route": "scheduled_agent",
                "mode": "daily_brief",
                "modelRoute": "local_skill",
                "contextAvailable": bool(events or reminders),
                "enabled": bool(agent.get("enabled")),
            },
        }

    def _ensure_defaults(self) -> None:
        agents = self._load() if self.config_path.exists() else {}
        if "daily_brief" not in agents:
            agents["daily_brief"] = {
                "id": "daily_brief",
                "name": "Daily Brief",
                "description": "Short opt-in summary from enabled local sources.",
                "type": "scheduled",
                "enabled": False,
                "time": "08:30",
                "timezone": os.environ.get("TZ") or "America/New_York",
                "sources": dict(self.DEFAULT_SOURCES),
                "requiresOptIn": True,
                "lastRunAt": None,
                "updatedAt": datetime.now().astimezone().isoformat(),
            }
            self._save(agents)

    def _load(self) -> Dict[str, dict]:
        if not self.config_path.exists():
            return {}
        try:
            data = json.loads(self.config_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
        agents = data.get("agents", {}) if isinstance(data, dict) else {}
        return agents if isinstance(agents, dict) else {}

    def _save(self, agents: Dict[str, dict]) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        self.config_path.write_text(json.dumps({"agents": agents}, indent=2, sort_keys=True), encoding="utf-8")

    def _with_runtime_fields(self, agent: dict) -> dict:
        copy = dict(agent)
        copy["nextRunAt"] = self._next_run_at(str(copy.get("time") or "08:30"), str(copy.get("timezone") or "UTC"))
        return copy

    def _next_run_at(self, hour_minute: str, timezone: str) -> str:
        try:
            tz = ZoneInfo(timezone)
        except Exception:
            tz = ZoneInfo("UTC")
        try:
            hour, minute = [int(part) for part in hour_minute.split(":", 1)]
            target_time = time(hour=hour, minute=minute)
        except Exception:
            target_time = time(hour=8, minute=30)
        now = datetime.now(tz)
        target = datetime.combine(now.date(), target_time, tzinfo=tz)
        if target <= now:
            target += timedelta(days=1)
        return target.isoformat()

    def _calendar_line(self, events: list, schedule: dict) -> str:
        if not events:
            auth = schedule.get("calendarAuthorization")
            if auth and auth not in {"fullAccess", "authorized"}:
                return f"Calendar: no events available ({auth})."
            return "Calendar: no events in the provided snapshot."
        items = ", ".join(self._item_label(item) for item in events[:3])
        suffix = "" if len(events) <= 3 else f" and {len(events) - 3} more"
        return f"Calendar: {items}{suffix}."

    def _reminders_line(self, reminders: list, schedule: dict) -> str:
        active = [item for item in reminders if not item.get("completed")]
        if not active:
            auth = schedule.get("reminderAuthorization")
            if auth and auth not in {"fullAccess", "authorized"}:
                return f"Reminders: none available ({auth})."
            return "Reminders: none due in the provided snapshot."
        items = ", ".join(self._item_label(item) for item in active[:3])
        suffix = "" if len(active) <= 3 else f" and {len(active) - 3} more"
        return f"Reminders: {items}{suffix}."

    def _item_label(self, item: dict) -> str:
        title = str(item.get("title") or "Untitled").strip()
        start = self._short_time(item.get("start"))
        return f"{title} at {start}" if start else title

    def _short_time(self, value: Any) -> str:
        if not value:
            return ""
        text = str(value)
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return ""
        return parsed.strftime("%-I:%M %p")

    def _brief_speak(self, events: list, reminders: list, sources: dict) -> str:
        if not sources.get("calendar") and not sources.get("reminders"):
            return "Daily brief has no enabled local sources yet."
        event_count = len(events) if sources.get("calendar") else 0
        reminder_count = len([item for item in reminders if not item.get("completed")]) if sources.get("reminders") else 0
        if event_count == 0 and reminder_count == 0:
            return "Daily brief preview ready. I don't see any events or reminders in the snapshot."
        return f"Daily brief preview ready: {event_count} events and {reminder_count} reminders."
