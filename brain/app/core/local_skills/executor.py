from __future__ import annotations

from typing import Optional

from .registry import LocalSkillRegistry
from .skill import LocalSkillInvocation, LocalSkillResult


class LocalSkillExecutor:
    def __init__(self, registry: LocalSkillRegistry) -> None:
        self.registry = registry

    def run_best(self, invocation: LocalSkillInvocation) -> Optional[LocalSkillResult]:
        skill = self.registry.match(invocation)
        if skill is None:
            return None
        result = skill.run(invocation)
        result.metadata.setdefault("route", "local_skill")
        result.metadata.setdefault("selectedSkill", skill.id)
        result.metadata.setdefault("selectedCapability", self._capability_id(skill.id))
        result.metadata.setdefault("riskLevel", skill.risk_level)
        return result

    def _capability_id(self, skill_id: str) -> str:
        mapping = {
            "app.open": "mac.open_app",
            "browser.open_url": "mac.open_url",
            "screenshot.take": "mac.take_screenshot",
            "time.now": "assistant.answer_general_question",
            "date.today": "assistant.answer_general_question",
            "system.status": "assistant.use_current_context",
            "assistant.pause_listening": "settings.manage_prompts",
            "assistant.resume_listening": "settings.manage_prompts",
            "assistant.go_offline": "settings.manage_prompts",
        }
        return mapping.get(skill_id, f"skills.{skill_id}")
