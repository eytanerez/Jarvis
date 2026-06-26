from __future__ import annotations

import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import uuid4

from .situation import Situation


class TurnTrace:
    def __init__(self, mode: str) -> None:
        self.started = time.perf_counter()
        self.data: Dict[str, Any] = {
            "turnId": uuid4().hex,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "mode": mode,
            "intent": None,
            "situation": {},
            "skillCandidates": [],
            "capabilitiesConsidered": [],
            "unavailableCapabilities": [],
            "selectedCapability": None,
            "selectedSkill": None,
            "skillLoaded": False,
            "modelRoute": None,
            "contextUsed": [],
            "latencyMs": 0,
            "fallbackUsed": False,
            "requiresConfirmation": False,
            "warnings": [],
        }

    def set_situation(self, situation: Situation) -> None:
        self.data["intent"] = situation.intent
        self.data["situation"] = {
            "resolvedTarget": situation.resolved_target,
            "targetSource": situation.target_source,
            "confidence": situation.confidence,
            "needsContext": situation.needs_context,
            "contextAvailable": situation.context_available,
        }

    def set_skill_candidates(self, candidates: List[Dict[str, Any]]) -> None:
        self.data["skillCandidates"] = candidates[:8]

    def set_capabilities(self, available_ids: List[str], unavailable_ids: List[str]) -> None:
        self.data["capabilitiesConsidered"] = available_ids[:16]
        self.data["unavailableCapabilities"] = unavailable_ids[:16]

    def set_selected_capability(self, capability_id: Optional[str]) -> None:
        self.data["selectedCapability"] = capability_id

    def set_selected_skill(self, name: Optional[str], loaded: bool = False) -> None:
        self.data["selectedSkill"] = name
        self.data["skillLoaded"] = loaded

    def set_model_route(self, route: str) -> None:
        self.data["modelRoute"] = route

    def add_context(self, source: str) -> None:
        if source and source not in self.data["contextUsed"]:
            self.data["contextUsed"].append(source)

    def warn(self, message: str) -> None:
        if message:
            self.data["warnings"].append(message)

    def finalize(self, requires_confirmation: bool = False) -> Dict[str, Any]:
        self.data["latencyMs"] = round((time.perf_counter() - self.started) * 1000.0, 2)
        self.data["requiresConfirmation"] = requires_confirmation
        return dict(self.data)
