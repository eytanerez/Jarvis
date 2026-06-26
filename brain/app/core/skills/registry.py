from __future__ import annotations

from pathlib import Path
from typing import Dict, Iterable, Optional

from .loader import SkillLoader
from .security import SkillSecurity
from .skill import Skill


class SkillRegistry:
    def __init__(self, roots: Iterable[Path], loader: Optional[SkillLoader] = None) -> None:
        self.roots = [Path(root).expanduser() for root in roots]
        self.loader = loader or SkillLoader()
        self.security = SkillSecurity()
        self._skills: Dict[str, Skill] = {}
        self.reload()

    def reload(self) -> None:
        skills: Dict[str, Skill] = {}
        for root in self.roots:
            if not root.exists():
                continue
            for path in root.rglob("SKILL.md"):
                if any(part.startswith(".") for part in path.relative_to(root).parts[:-1]):
                    continue
                try:
                    skill = self.loader.load(path.parent)
                except Exception:
                    continue
                skills[skill.name] = skill
        self._skills = skills

    def list(self) -> list[dict]:
        return sorted((skill.level0() for skill in self._skills.values()), key=lambda item: item["name"])

    def all(self) -> list[Skill]:
        return list(self._skills.values())

    def get(self, name: str) -> Optional[Skill]:
        return self._skills.get(self.security.sanitize_name(name))

    def add_loaded(self, skill: Skill) -> None:
        self._skills[skill.name] = skill
