from __future__ import annotations

from typing import Optional


class ConversationalRepair:
    def missing_context_prompt(self, reason: Optional[str] = None) -> str:
        if reason:
            return reason
        return "I need the selected text, current document, page, or visible message context for that."

    def one_question(self, missing: str) -> str:
        missing = missing.strip().rstrip(".")
        return f"I need {missing}. Which should I use?"
