from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Literal


ExecutionType = Literal["on_demand", "scheduled", "continuous"]


@dataclass(frozen=True)
class AssistantMode:
    id: str
    name: str
    purpose: str
    trigger: str
    execution_type: ExecutionType
    default_model_route: str
    allowed_skills: List[str] = field(default_factory=list)
    context_policy: Dict[str, Any] = field(default_factory=dict)
    response_style: str = "natural_short"
    risk_policy: Dict[str, Any] = field(default_factory=dict)
    max_response_length: str = "short"
    speech_policy: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "purpose": self.purpose,
            "trigger": self.trigger,
            "executionType": self.execution_type,
            "defaultModelRoute": self.default_model_route,
            "allowedSkills": list(self.allowed_skills),
            "contextPolicy": dict(self.context_policy),
            "responseStyle": self.response_style,
            "riskPolicy": dict(self.risk_policy),
            "maxResponseLength": self.max_response_length,
            "speechPolicy": dict(self.speech_policy),
        }
