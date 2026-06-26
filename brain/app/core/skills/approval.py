from __future__ import annotations

import difflib
import json
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4


@dataclass
class PendingSkillChange:
    id: str
    action: str
    skill_name: str
    summary: str
    staged_path: Path
    target_path: Path
    created_at: str
    warnings: List[str]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "action": self.action,
            "skillName": self.skill_name,
            "summary": self.summary,
            "stagedPath": str(self.staged_path),
            "targetPath": str(self.target_path),
            "createdAt": self.created_at,
            "warnings": list(self.warnings),
        }


class SkillApprovalStore:
    def __init__(self, pending_root: Path, skills_root: Path) -> None:
        self.pending_root = Path(pending_root).expanduser()
        self.skills_root = Path(skills_root).expanduser()
        self.pending_root.mkdir(parents=True, exist_ok=True)

    def stage_skill(self, skill_name: str, content: str, category: str = "personal", summary: str = "Create learned skill.", warnings: Optional[List[str]] = None) -> PendingSkillChange:
        change_id = uuid4().hex[:12]
        staged_dir = self.pending_root / change_id
        staged_skill_dir = staged_dir / category / skill_name
        staged_skill_dir.mkdir(parents=True, exist_ok=True)
        (staged_skill_dir / "SKILL.md").write_text(content, encoding="utf-8")
        target_path = self.skills_root / category / skill_name
        change = PendingSkillChange(
            id=change_id,
            action="create",
            skill_name=skill_name,
            summary=summary,
            staged_path=staged_skill_dir,
            target_path=target_path,
            created_at=datetime.now(timezone.utc).isoformat(),
            warnings=list(warnings or []),
        )
        (staged_dir / "change.json").write_text(json.dumps(change.to_dict(), indent=2), encoding="utf-8")
        return change

    def stage_delete(self, skill_name: str, target_path: Path, summary: str = "Delete skill.", warnings: Optional[List[str]] = None) -> PendingSkillChange:
        change_id = uuid4().hex[:12]
        staged_dir = self.pending_root / change_id
        staged_dir.mkdir(parents=True, exist_ok=True)
        change = PendingSkillChange(
            id=change_id,
            action="delete",
            skill_name=skill_name,
            summary=summary,
            staged_path=Path(target_path),
            target_path=Path(target_path),
            created_at=datetime.now(timezone.utc).isoformat(),
            warnings=list(warnings or []),
        )
        (staged_dir / "change.json").write_text(json.dumps(change.to_dict(), indent=2), encoding="utf-8")
        return change

    def pending(self) -> List[Dict[str, Any]]:
        changes = []
        for path in sorted(self.pending_root.glob("*/change.json")):
            try:
                changes.append(json.loads(path.read_text(encoding="utf-8")))
            except Exception:
                continue
        return changes

    def get(self, change_id: str) -> PendingSkillChange:
        path = self.pending_root / change_id / "change.json"
        if not path.exists():
            raise KeyError(change_id)
        data = json.loads(path.read_text(encoding="utf-8"))
        return PendingSkillChange(
            id=data["id"],
            action=data["action"],
            skill_name=data["skillName"],
            summary=data["summary"],
            staged_path=Path(data["stagedPath"]),
            target_path=Path(data["targetPath"]),
            created_at=data["createdAt"],
            warnings=list(data.get("warnings") or []),
        )

    def diff(self, change_id: str) -> Dict[str, Any]:
        change = self.get(change_id)
        staged = "" if change.action == "delete" else (change.staged_path / "SKILL.md").read_text(encoding="utf-8")
        target_file = change.target_path / "SKILL.md"
        existing = target_file.read_text(encoding="utf-8") if target_file.exists() else ""
        diff = "\n".join(
            difflib.unified_diff(
                existing.splitlines(),
                staged.splitlines(),
                fromfile=str(target_file),
                tofile=str(change.staged_path / "SKILL.md"),
                lineterm="",
            )
        )
        data = change.to_dict()
        data["diff"] = diff
        return data

    def approve(self, change_id: str) -> Dict[str, Any]:
        change = self.get(change_id)
        if change.action == "delete":
            shutil.rmtree(change.target_path, ignore_errors=True)
        else:
            change.target_path.parent.mkdir(parents=True, exist_ok=True)
            if change.target_path.exists():
                shutil.rmtree(change.target_path)
            shutil.copytree(change.staged_path, change.target_path)
        shutil.rmtree(self.pending_root / change_id, ignore_errors=True)
        data = change.to_dict()
        data["approved"] = True
        return data

    def reject(self, change_id: str) -> Dict[str, Any]:
        change = self.get(change_id)
        shutil.rmtree(self.pending_root / change_id, ignore_errors=True)
        data = change.to_dict()
        data["rejected"] = True
        return data
