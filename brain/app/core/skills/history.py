from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
from uuid import uuid4


class SkillRunHistory:
    def __init__(self, audit_root: Path) -> None:
        self.audit_root = Path(audit_root).expanduser()
        self.audit_root.mkdir(parents=True, exist_ok=True)
        self.path = self.audit_root / "skill-runs.jsonl"

    def record(
        self,
        *,
        kind: str,
        name: str,
        route: str,
        status: str = "prepared",
        mode: Optional[str] = None,
        intent: Optional[str] = None,
        risk_level: Optional[str] = None,
        requires_confirmation: bool = False,
        loaded_skills: Optional[Iterable[str]] = None,
        missing_skills: Optional[Iterable[str]] = None,
        warnings: Optional[Iterable[str]] = None,
        input_summary: Optional[Dict[str, Any]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        record = {
            "id": uuid4().hex[:12],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "kind": kind,
            "name": name,
            "route": route,
            "status": status,
            "mode": mode,
            "intent": intent,
            "riskLevel": risk_level,
            "requiresConfirmation": bool(requires_confirmation),
            "loadedSkills": list(loaded_skills or []),
            "missingSkills": list(missing_skills or []),
            "warnings": list(warnings or []),
            "inputSummary": dict(input_summary or {}),
            "metadata": self._safe_metadata(metadata or {}),
        }
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
        return record

    def list(self, limit: int = 50) -> Dict[str, Any]:
        limit = max(1, min(int(limit or 50), 200))
        if not self.path.exists():
            return {"runs": []}
        records: List[Dict[str, Any]] = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(record, dict):
                records.append(record)
        return {"runs": list(reversed(records[-limit:]))}

    def _safe_metadata(self, metadata: Dict[str, Any]) -> Dict[str, Any]:
        allowed = [
            "modelRoute",
            "selectedBundle",
            "bundleInvocation",
            "provider",
            "privacyLevel",
            "why",
            "actionCount",
            "contextAvailable",
        ]
        return {key: metadata[key] for key in allowed if key in metadata}
