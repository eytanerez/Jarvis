from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass
class Situation:
    mode: str
    intent: str
    user_goal: str
    surface_reference: Optional[str] = None
    resolved_target: Optional[str] = None
    target_source: Optional[str] = None
    confidence: float = 0.0
    needs_context: bool = False
    context_available: bool = False
    missing_context_reason: Optional[str] = None
    preferred_response_style: str = "short_natural"
    likely_skill: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "mode": self.mode,
            "intent": self.intent,
            "userGoal": self.user_goal,
            "surfaceReference": self.surface_reference,
            "resolvedTarget": self.resolved_target,
            "targetSource": self.target_source,
            "confidence": self.confidence,
            "needsContext": self.needs_context,
            "contextAvailable": self.context_available,
            "missingContextReason": self.missing_context_reason,
            "preferredResponseStyle": self.preferred_response_style,
            "likelySkill": self.likely_skill,
        }
