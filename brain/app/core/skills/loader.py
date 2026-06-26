from __future__ import annotations

import ast
import re
from pathlib import Path
from typing import Any, Dict, Tuple

from .security import SkillSecurity
from .skill import Skill, SkillMetadata


class SkillLoader:
    def __init__(self, security: SkillSecurity | None = None) -> None:
        self.security = security or SkillSecurity()

    def load(self, skill_dir: Path) -> Skill:
        path = skill_dir / "SKILL.md"
        if not path.exists():
            raise FileNotFoundError(f"Missing SKILL.md in {skill_dir}")
        raw = path.read_text(encoding="utf-8")
        metadata, body = self._parse(raw)
        metadata.name = self.security.sanitize_name(metadata.name or skill_dir.name)
        warnings = self.security.find_secret_warnings(raw)
        warnings.extend(self._script_warnings(skill_dir))
        return Skill(metadata=metadata, body=body, path=path, raw=raw, warnings=warnings)

    def load_file(self, path: Path) -> str:
        return path.read_text(encoding="utf-8")

    def _parse(self, raw: str) -> Tuple[SkillMetadata, str]:
        if raw.startswith("---\n"):
            end = raw.find("\n---", 4)
            if end != -1:
                frontmatter = raw[4:end].strip()
                body = raw[end + 4 :].lstrip("\n")
                return SkillMetadata.from_dict(self._parse_frontmatter(frontmatter)), body
        return SkillMetadata.from_dict({"name": "untitled-skill", "description": ""}), raw

    def _parse_frontmatter(self, text: str) -> Dict[str, Any]:
        data: Dict[str, Any] = {}
        current_key: str | None = None
        current_list: list[Dict[str, Any]] | None = None
        for raw_line in text.splitlines():
            line = raw_line.rstrip()
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.startswith("  - ") and current_key:
                if current_list is None:
                    current_list = []
                    data[current_key] = current_list
                item_text = line[4:].strip()
                if ":" in item_text:
                    key, value = item_text.split(":", 1)
                    current_list.append({key.strip(): self._parse_scalar(value.strip())})
                else:
                    current_list.append({"value": self._parse_scalar(item_text)})
                continue
            if line.startswith("    ") and current_list:
                key, value = line.strip().split(":", 1)
                current_list[-1][key.strip()] = self._parse_scalar(value.strip())
                continue
            current_list = None
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            current_key = key.strip()
            value = value.strip()
            data[current_key] = [] if value == "" else self._parse_scalar(value)
        return data

    def _parse_scalar(self, value: str) -> Any:
        if value in {"true", "True"}:
            return True
        if value in {"false", "False"}:
            return False
        if value in {"[]", ""}:
            return [] if value == "[]" else ""
        if value.startswith("[") and value.endswith("]"):
            try:
                return ast.literal_eval(value)
            except Exception:
                inner = value[1:-1].strip()
                return [item.strip().strip("'\"") for item in inner.split(",") if item.strip()]
        if re.match(r"^\d+\.\d+\.\d+$", value):
            return value
        return value.strip("'\"")

    def _script_warnings(self, skill_dir: Path) -> list[str]:
        scripts = skill_dir / "scripts"
        if not scripts.exists():
            return []
        texts = []
        for path in scripts.rglob("*"):
            if path.is_file() and path.stat().st_size <= 200_000:
                try:
                    texts.append(path.read_text(encoding="utf-8", errors="ignore"))
                except OSError:
                    continue
        return self.security.find_script_warnings(texts)
