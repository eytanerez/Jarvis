from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable, List


SECRET_PATTERNS = [
    re.compile(r"(?i)\b(api[_-]?key|token|password|secret|cookie|private[_-]?key)\b\s*[:=]\s*['\"]?[^'\"\s]{8,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
]

# Denylist of obviously risky shell snippets. This is signage, not a sandbox:
# it is trivially evadable (flag reordering, obfuscation) and must never be
# treated as a reason to skip the human confirmation step, which is the real
# boundary. Compiled case-insensitively so "RM -RF" is flagged like "rm -rf".
DANGEROUS_SCRIPT_PATTERNS = [
    re.compile(r"\brm\s+-rf\b", re.IGNORECASE),
    re.compile(r"\bsudo\b", re.IGNORECASE),
    re.compile(r"\bcurl\b.+\|\s*(sh|bash|zsh)\b", re.IGNORECASE),
    re.compile(r"\bchmod\s+777\b", re.IGNORECASE),
]


class SkillSecurity:
    def sanitize_name(self, value: str) -> str:
        name = re.sub(r"[^a-z0-9._-]+", "-", value.strip().lower())
        name = re.sub(r"-{2,}", "-", name).strip("-._")
        return name[:80] or "untitled-skill"

    def validate_relative_path(self, root: Path, relative: str) -> Path:
        candidate = (root / relative).resolve()
        root_resolved = root.resolve()
        if root_resolved not in candidate.parents and candidate != root_resolved:
            raise ValueError("Path escapes the skill directory.")
        return candidate

    def find_secret_warnings(self, text: str) -> List[str]:
        warnings: List[str] = []
        for pattern in SECRET_PATTERNS:
            if pattern.search(text):
                warnings.append("Potential secret-like content was detected and must be removed before approval.")
                break
        return warnings

    def find_script_warnings(self, texts: Iterable[str]) -> List[str]:
        warnings: List[str] = []
        combined = "\n".join(texts)
        for pattern in DANGEROUS_SCRIPT_PATTERNS:
            if pattern.search(combined):
                warnings.append("Potentially dangerous script command detected; review explicitly before trusting this skill.")
                break
        return warnings

    def redacted(self, text: str) -> str:
        redacted = text
        for pattern in SECRET_PATTERNS:
            redacted = pattern.sub("[REDACTED_SECRET]", redacted)
        return redacted
