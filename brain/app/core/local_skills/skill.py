from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional

from ..situation import Situation


@dataclass
class LocalSkillInvocation:
    message: str
    lower: str
    mode: str
    context: Optional[Dict[str, Any]]
    session: Dict[str, Any]
    situation: Optional[Situation] = None


@dataclass
class LocalSkillResult:
    answer: str
    speak: Optional[str] = None
    results: List[Dict[str, Any]] = field(default_factory=list)
    actions: List[Dict[str, Any]] = field(default_factory=list)
    requires_confirmation: bool = False
    confirmation: Optional[Dict[str, Any]] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    model_used: str = "Local skill"


Matcher = Callable[[LocalSkillInvocation], bool]
Runner = Callable[[LocalSkillInvocation], LocalSkillResult]


@dataclass
class LocalSkill:
    id: str
    name: str
    description: str
    risk_level: str
    allowed_modes: List[str]
    match: Matcher
    run: Runner
    requires_confirmation: bool = False

    def summary(self) -> Dict[str, Any]:
        return {
            "name": self.id,
            "description": self.description,
            "category": "local",
            "riskLevel": self.risk_level,
            "allowedModes": list(self.allowed_modes),
            "requiresConfirmation": self.requires_confirmation,
        }
