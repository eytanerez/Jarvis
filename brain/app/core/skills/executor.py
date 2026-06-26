from __future__ import annotations

from typing import Any, Dict, Optional

from .skill import Skill


class SkillExecutor:
    def run(
        self,
        skill: Skill,
        inputs: Optional[Dict[str, Any]] = None,
        dry_run: bool = True,
    ) -> Dict[str, Any]:
        inputs = inputs or {}
        metadata = skill.metadata
        action = {
            "id": f"run_skill_{metadata.name}",
            "type": "run_skill",
            "payload": {
                "skill": metadata.name,
                "dryRun": dry_run,
                "inputs": inputs,
            },
        }
        requires_confirmation = metadata.requires_confirmation or metadata.risk_level in {"yellow", "red"}
        confirmation = None
        if requires_confirmation:
            confirmation = {
                "id": f"confirm_run_skill_{metadata.name}",
                "risk": metadata.risk_level,
                "title": f"Run {metadata.name}?",
                "description": metadata.description or "Run this Jarvis skill.",
                "action": action,
                "requiresTypedConfirmation": metadata.risk_level == "red",
            }
        return {
            "answer": self._answer(skill, requires_confirmation),
            "speak": "Review before running." if requires_confirmation else "Running skill.",
            "results": [],
            "actions": [action],
            "requiresConfirmation": requires_confirmation,
            "confirmation": confirmation,
            "modelUsed": "Skill executor",
            "metadata": {
                "route": "skill_execution",
                "selectedSkill": metadata.name,
                "riskLevel": metadata.risk_level,
                "skillLoaded": True,
                "dryRun": dry_run,
            },
        }

    def _answer(self, skill: Skill, requires_confirmation: bool) -> str:
        if requires_confirmation:
            return f"I found the `{skill.name}` skill. Review it before I run it."
        return f"I found the `{skill.name}` skill and prepared it to run."
