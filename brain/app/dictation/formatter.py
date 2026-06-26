from __future__ import annotations

import re
from typing import Optional


class DictationFormatter:
    def format(self, text: str, active_app: Optional[str] = None) -> str:
        app = (active_app or "").lower()
        if any(name in app for name in ["mail", "gmail", "outlook"]):
            return self._email(text)
        if any(name in app for name in ["messages", "whatsapp"]):
            return self._message(text)
        if any(name in app for name in ["xcode", "code", "cursor", "terminal"]):
            return text.strip()
        return self._plain(text)

    def _email(self, text: str) -> str:
        cleaned = text.strip()
        match = re.search(r"\bbest[, ]+([A-Z][A-Za-z]+)$", cleaned)
        if match:
            prefix = cleaned[: match.start()].strip()
            if re.match(r"(?i)^(can|could|would|will|should|do|does|did|is|are)\b", prefix) and not prefix.endswith(("?", ".", "!")):
                prefix += "?"
            return f"{prefix}\n\nBest,\n{match.group(1)}"
        return cleaned

    def _message(self, text: str) -> str:
        return text.strip()

    def _plain(self, text: str) -> str:
        return text.strip()
