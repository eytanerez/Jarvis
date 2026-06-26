from __future__ import annotations

import re
from typing import Any, Dict, List, Optional


class AssistantResponseComposer:
    def compose(
        self,
        answer: str,
        speak: Optional[str] = None,
        results: Optional[List[Dict[str, Any]]] = None,
        actions: Optional[List[Dict[str, Any]]] = None,
        requires_confirmation: bool = False,
        confirmation: Optional[Dict[str, Any]] = None,
        model_used: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
        memory_updates: Optional[List[Dict[str, Any]]] = None,
        skill_updates: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        clean_answer = self._clean(answer)
        clean_speak = self._short_speak(speak if speak is not None else clean_answer)
        action_list = actions or []
        merged_metadata = dict(metadata or {})
        merged_metadata.setdefault("actionCount", len(action_list))
        return {
            "answer": clean_answer,
            "speak": clean_speak,
            "results": results or [],
            "actions": action_list,
            "memoryUpdates": memory_updates or [],
            "skillUpdates": skill_updates or [],
            "requiresConfirmation": requires_confirmation,
            "confirmation": confirmation,
            "modelUsed": model_used,
            "metadata": merged_metadata,
        }

    def from_local_skill(self, result: Any) -> Dict[str, Any]:
        return self.compose(
            result.answer,
            speak=result.speak,
            results=result.results,
            actions=result.actions,
            requires_confirmation=result.requires_confirmation,
            confirmation=result.confirmation,
            model_used=result.model_used,
            metadata=result.metadata,
        )

    def _clean(self, answer: str) -> str:
        text = str(answer or "").strip()
        text = re.sub(r"(?i)\bas an ai[, ]*", "", text)
        text = re.sub(r"(?i)\bi have completed the requested operation\.?", "Done.", text)
        return text or "Done."

    def _short_speak(self, text: str) -> str:
        clean = self._clean(text)
        sentences = re.split(r"(?<=[.!?])\s+", clean)
        short = " ".join(sentences[:2]).strip()
        return short[:280].rstrip() or clean[:280]
