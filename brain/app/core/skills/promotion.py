from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass(frozen=True)
class SkillPromotionDecision:
    should_suggest: bool
    reason: str = ""
    prompt: str = ""
    warnings: tuple[str, ...] = ()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "shouldSuggest": self.should_suggest,
            "reason": self.reason,
            "prompt": self.prompt,
            "warnings": list(self.warnings),
        }


class SkillPromotionPolicy:
    explicit_phrases = (
        "learn this",
        "make this a skill",
        "remember how to do this",
        "save this workflow",
    )
    reusable_phrases = (
        "workflow",
        "process",
        "every time",
        "next time",
        "repeat this",
        "do this again",
        "outreach",
        "playbook",
        "checklist",
    )
    sensitive_terms = (
        "password",
        "api key",
        "secret",
        "token",
        "private key",
        "ssn",
        "social security",
        "credit card",
    )

    def evaluate(
        self,
        message: str,
        response: Dict[str, Any],
        situation: Optional[Any] = None,
    ) -> SkillPromotionDecision:
        lower = message.lower()
        if any(term in lower for term in self.sensitive_terms):
            return SkillPromotionDecision(False, "sensitive_content")
        if response.get("requiresConfirmation") or response.get("skillUpdates"):
            return SkillPromotionDecision(False, "pending_confirmation_or_skill_update")
        metadata = response.get("metadata") or {}
        route = str(metadata.get("route") or "")
        if route in {"context_missing", "memory", "skill_admin", "skill_learning", "local_skill"}:
            return SkillPromotionDecision(False, f"route_{route}")
        if any(phrase in lower for phrase in self.explicit_phrases):
            return SkillPromotionDecision(
                True,
                "explicit_user_request",
                "I can save this as a reusable skill so next time it is faster. Want me to stage it?",
            )
        if not any(phrase in lower for phrase in self.reusable_phrases):
            return SkillPromotionDecision(False, "not_reusable_enough")
        answer = str(response.get("answer") or "")
        if not answer.strip():
            return SkillPromotionDecision(False, "empty_response")
        if any(word in lower for word in ["failed", "didn't work", "wrong", "not right"]):
            return SkillPromotionDecision(False, "workflow_not_successful")
        return SkillPromotionDecision(
            True,
            "reusable_workflow_signal",
            "I can save this as a reusable skill so next time it is faster. Want me to stage it?",
        )
