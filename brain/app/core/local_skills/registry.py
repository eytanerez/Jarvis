from __future__ import annotations

from typing import Iterable, List, Optional

from .skill import LocalSkill, LocalSkillInvocation


class LocalSkillRegistry:
    def __init__(self, skills: Optional[Iterable[LocalSkill]] = None) -> None:
        self._skills: List[LocalSkill] = list(skills or [])

    def register(self, skill: LocalSkill) -> None:
        self._skills = [existing for existing in self._skills if existing.id != skill.id]
        self._skills.append(skill)

    def list(self) -> list[dict]:
        return [skill.summary() for skill in self._skills]

    def get(self, skill_id: str) -> Optional[LocalSkill]:
        return next((skill for skill in self._skills if skill.id == skill_id), None)

    def match(self, invocation: LocalSkillInvocation) -> Optional[LocalSkill]:
        for skill in self._skills:
            if invocation.mode not in skill.allowed_modes and "*" not in skill.allowed_modes:
                continue
            if skill.match(invocation):
                return skill
        return None
