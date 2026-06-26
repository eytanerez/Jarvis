from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional


@dataclass
class WorkingContext:
    current_task: Optional[str] = None
    current_subject: Optional[str] = None
    current_app: Optional[str] = None
    current_document_path: Optional[str] = None
    current_document_title: Optional[str] = None
    last_selected_text: Optional[str] = None
    last_resolved_target: Optional[str] = None
    last_result_type: Optional[str] = None
    last_results: List[Any] = field(default_factory=list)
    last_action: Optional[Dict[str, Any]] = None
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @classmethod
    def from_session(cls, session: Optional[Dict[str, Any]]) -> "WorkingContext":
        session = session or {}
        raw_updated = session.get("updatedAt") or session.get("updated_at")
        updated = cls._parse_datetime(raw_updated) or datetime.now(timezone.utc)
        return cls(
            current_task=session.get("currentTask") or session.get("current_task"),
            current_subject=session.get("currentSubject") or session.get("current_subject"),
            current_app=session.get("currentApp") or session.get("current_app"),
            current_document_path=session.get("currentDocumentPath") or session.get("current_document_path"),
            current_document_title=session.get("currentDocumentTitle") or session.get("current_document_title"),
            last_selected_text=session.get("lastSelectedText") or session.get("last_selected_text"),
            last_resolved_target=session.get("lastResolvedTarget") or session.get("last_resolved_target"),
            last_result_type=session.get("lastResultType") or session.get("last_result_type"),
            last_results=list(session.get("lastResults") or session.get("last_results") or []),
            last_action=session.get("lastAction") or session.get("last_action"),
            updated_at=updated,
        )

    def is_fresh(self, current_app: Optional[str] = None, max_age_minutes: int = 60) -> bool:
        age = datetime.now(timezone.utc) - self.updated_at
        if age > timedelta(minutes=max_age_minutes):
            return False
        if current_app and self.current_app and current_app != self.current_app:
            return False
        return True

    def to_dict(self) -> Dict[str, Any]:
        return {
            "currentTask": self.current_task,
            "currentSubject": self.current_subject,
            "currentApp": self.current_app,
            "currentDocumentPath": self.current_document_path,
            "currentDocumentTitle": self.current_document_title,
            "lastSelectedText": self.last_selected_text,
            "lastResolvedTarget": self.last_resolved_target,
            "lastResultType": self.last_result_type,
            "lastResults": self.last_results,
            "lastAction": self.last_action,
            "updatedAt": self.updated_at.isoformat(),
        }

    @staticmethod
    def _parse_datetime(value: Any) -> Optional[datetime]:
        if not value:
            return None
        try:
            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed
        except ValueError:
            return None
