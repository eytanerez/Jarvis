from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

from .security import SkillSecurity


class SkillBundleStore:
    def __init__(self, root: Path) -> None:
        self.root = Path(root).expanduser()
        self.root.mkdir(parents=True, exist_ok=True)
        self.security = SkillSecurity()

    def list(self) -> List[Dict[str, Any]]:
        bundles = []
        for path in sorted(self.root.glob("*.yaml")):
            bundles.append(self._load(path))
        for path in sorted(self.root.glob("*.yml")):
            bundles.append(self._load(path))
        return bundles

    def get(self, name: str) -> Optional[Dict[str, Any]]:
        safe = self.security.sanitize_name(name)
        for suffix in [".yaml", ".yml"]:
            path = self.root / f"{safe}{suffix}"
            if path.exists():
                return self._load(path)
        return None

    def save(self, data: Dict[str, Any]) -> Dict[str, Any]:
        name = self.security.sanitize_name(str(data.get("name") or "untitled-bundle"))
        content = self._dump(data | {"name": name})
        path = self.root / f"{name}.yaml"
        path.write_text(content, encoding="utf-8")
        return self._load(path)

    def match_invocation(self, message: str) -> Optional[Dict[str, Any]]:
        lower = message.lower().strip()
        if not lower:
            return None
        for bundle in self.list():
            name = str(bundle.get("name") or "")
            safe = self.security.sanitize_name(name)
            slash_prefixes = [f"/{safe}", f"/{safe.replace('-', '_')}", f"/{safe.replace('-', ' ')}"]
            for prefix in slash_prefixes:
                if lower == prefix or lower.startswith(prefix + " "):
                    return {
                        "bundle": bundle,
                        "query": message[len(prefix):].strip() if lower.startswith(prefix) else "",
                        "source": "slash",
                    }
            if self._natural_match(lower, safe, str(bundle.get("description") or "")):
                return {"bundle": bundle, "query": message, "source": "natural_language"}
        return None

    def _load(self, path: Path) -> Dict[str, Any]:
        data: Dict[str, Any] = {"name": path.stem, "description": "", "skills": [], "instruction": ""}
        current_key: str | None = None
        instruction_lines: List[str] = []
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            stripped = line.strip()
            if not stripped:
                if current_key == "instruction":
                    instruction_lines.append("")
                continue
            if stripped.startswith("- ") and current_key == "skills":
                data["skills"].append(stripped[2:].strip())
                continue
            if line.startswith("  ") and current_key == "instruction":
                instruction_lines.append(line[2:])
                continue
            if ":" in stripped:
                key, value = stripped.split(":", 1)
                current_key = key
                value = value.strip()
                if key == "skills":
                    data["skills"] = []
                elif key == "instruction":
                    data["instruction"] = value.lstrip("|").strip()
                else:
                    data[key] = value.strip("'\"")
        if instruction_lines:
            data["instruction"] = "\n".join(instruction_lines).strip()
        data["path"] = str(path)
        return data

    def _dump(self, data: Dict[str, Any]) -> str:
        skills = data.get("skills") or []
        lines = [
            f"name: {data.get('name', 'untitled-bundle')}",
            f"description: {data.get('description', '')}",
            "skills:",
        ]
        lines.extend(f"  - {skill}" for skill in skills)
        instruction = str(data.get("instruction") or "").rstrip()
        lines.append("instruction: |")
        lines.extend(f"  {line}" for line in instruction.splitlines() or [""])
        return "\n".join(lines) + "\n"

    def _natural_match(self, lower: str, safe_name: str, description: str) -> bool:
        tokens = [token for token in safe_name.replace("_", "-").split("-") if len(token) > 2]
        if not tokens or not all(token in lower for token in tokens):
            return False
        workflow_words = ["prep", "prepare", "workflow", "bundle", "launch", "meeting", "research", "draft", "review", "compare", "plan"]
        haystack = f"{lower} {description.lower()}"
        return any(word in haystack for word in workflow_words)
