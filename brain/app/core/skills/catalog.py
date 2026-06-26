from __future__ import annotations

from typing import Any, Dict, Optional

from .registry import SkillRegistry
from .security import SkillSecurity


class SkillCatalog:
    def __init__(self, registry: SkillRegistry) -> None:
        self.registry = registry
        self.security = SkillSecurity()

    def skills_list(self) -> list[dict]:
        return self.registry.list()

    def skill_view(self, name: str, path: Optional[str] = None) -> Dict[str, Any]:
        skill = self.registry.get(name)
        if skill is None:
            raise KeyError(f"Skill not found: {name}")
        if path:
            file_path = self.security.validate_relative_path(skill.path.parent, path)
            if not file_path.exists() or not file_path.is_file():
                raise FileNotFoundError(path)
            return {
                "name": skill.name,
                "path": path,
                "content": file_path.read_text(encoding="utf-8", errors="ignore"),
            }
        return skill.level1()
