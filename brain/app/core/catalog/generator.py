from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from .definitions import CATALOG
from .models import CATALOG_VERSION
from .render import render_skill_md


class SkillCatalogGenerator:
    """Writes the canonical catalog to real SKILL.md files under the skills root.

    Replaces the old per-folder builtin generator. Because the catalog is the
    single source of truth, no two managed files can share a `name:`.
    """

    MARKER = ".catalog-version"

    def __init__(self, skills_root: Path) -> None:
        self.skills_root = Path(skills_root)

    def ensure(self) -> Dict[str, object]:
        self.skills_root.mkdir(parents=True, exist_ok=True)
        marker = self.skills_root / self.MARKER
        current = marker.read_text(encoding="utf-8").strip() if marker.exists() else ""
        force = current != CATALOG_VERSION

        written: List[str] = []
        for defn in CATALOG:
            skill_dir = self.skills_root / defn.category / defn.name
            skill_file = skill_dir / "SKILL.md"
            if skill_file.exists() and not force:
                continue
            skill_dir.mkdir(parents=True, exist_ok=True)
            skill_file.write_text(render_skill_md(defn), encoding="utf-8")
            written.append(defn.path)

        if force:
            marker.write_text(CATALOG_VERSION, encoding="utf-8")

        return {
            "version": CATALOG_VERSION,
            "skillCount": len(CATALOG),
            "writtenCount": len(written),
            "regenerated": force,
        }

    def categories(self) -> List[str]:
        return sorted({defn.category for defn in CATALOG})
