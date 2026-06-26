from __future__ import annotations

import re
from typing import Optional

from ..situation import Situation
from .registry import SkillRegistry
from .skill import Skill


class SkillMatcher:
    def __init__(self, registry: SkillRegistry) -> None:
        self.registry = registry

    def best_match(self, message: str, mode: str, situation: Optional[Situation] = None) -> Optional[Skill]:
        if situation and situation.likely_skill:
            direct = self.registry.get(situation.likely_skill)
            if direct and self._mode_allowed(direct, mode):
                return direct
        lower = message.lower()
        candidates = []
        for skill in self.registry.all():
            if not self._mode_allowed(skill, mode):
                continue
            score = self._score(skill, lower)
            if score > 0:
                candidates.append((score, skill))
        if not candidates:
            return None
        candidates.sort(key=lambda item: item[0], reverse=True)
        return candidates[0][1]

    def candidates(self, message: str, mode: str) -> list[dict]:
        lower = message.lower()
        scored = []
        for skill in self.registry.all():
            if not self._mode_allowed(skill, mode):
                continue
            score = self._score(skill, lower)
            if score > 0:
                item = skill.level0()
                item["score"] = score
                scored.append(item)
        return sorted(scored, key=lambda item: item["score"], reverse=True)

    def _mode_allowed(self, skill: Skill, mode: str) -> bool:
        modes = skill.metadata.allowed_modes
        return "*" in modes or mode in modes

    def _score(self, skill: Skill, lower: str) -> int:
        score = 0
        terms = set(re.findall(r"[a-z0-9]+", lower))
        haystack = f"{skill.name} {skill.metadata.description} {skill.metadata.category}".lower()
        for term in terms:
            if len(term) > 2 and term in haystack:
                score += 2
        for section in ["When to Use", "Inputs Needed"]:
            marker = f"## {section}"
            if marker in skill.body:
                snippet = skill.body.split(marker, 1)[1][:600].lower()
                for term in terms:
                    if len(term) > 3 and term in snippet:
                        score += 1
        return score
