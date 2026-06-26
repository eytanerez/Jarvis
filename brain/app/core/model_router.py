from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional

from .situation import Situation


@dataclass
class ModelRoute:
    model_route: str
    task_type: str
    why: str
    latency_target_ms: int = 1000
    privacy_level: str = "balanced"

    def to_metadata(self) -> Dict[str, Any]:
        return {
            "modelRoute": self.model_route,
            "taskType": self.task_type,
            "why": self.why,
            "latencyTargetMs": self.latency_target_ms,
            "privacyLevel": self.privacy_level,
        }


class ModelRouter:
    def choose(
        self,
        message: str,
        mode: str,
        situation: Optional[Situation] = None,
        local_skill_available: bool = False,
        context: Optional[Dict[str, Any]] = None,
        requested_task_type: Optional[str] = None,
    ) -> ModelRoute:
        if local_skill_available:
            return ModelRoute("local_skill", "local", "deterministic local skill matched", 500, "local")
        if self._local_only(context):
            return ModelRoute("local_small", "fast", "local-only privacy mode is enabled", 1000, "local")
        if requested_task_type in {"fast", "smart", "reasoning"}:
            task = "smart" if requested_task_type == "reasoning" else requested_task_type
            return ModelRoute(f"gemini_{task}", task, f"caller requested {requested_task_type}", 4000 if task == "smart" else 1600)
        if mode in {"deep_research", "code_helper"}:
            return ModelRoute("gemini_smart", "smart", f"{mode} needs deeper reasoning", 6000)
        if situation and situation.intent in {"summarize_context", "rewrite_context", "draft_reply", "skill_learning"}:
            return ModelRoute("gemini_fast", "fast", f"{situation.intent} needs language generation", 2500)
        lower = message.lower()
        if any(term in lower for term in ["compare", "analyze", "plan", "think through", "evaluate", "tradeoff"]):
            return ModelRoute("gemini_smart", "smart", "request asks for analysis", 6000)
        return ModelRoute("gemini_fast", "fast", "default assistant route", 2500)

    def _local_only(self, context: Optional[Dict[str, Any]]) -> bool:
        settings = (context or {}).get("settings") or {}
        privacy = settings.get("privacy") or settings.get("context") or {}
        return bool(privacy.get("localOnlyMode"))
