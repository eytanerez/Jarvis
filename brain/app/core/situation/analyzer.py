from __future__ import annotations

import re
from typing import Any, Dict, Optional

from .reference_resolver import ReferenceResolver
from .situation import Situation


class SituationAnalyzer:
    def __init__(self, resolver: Optional[ReferenceResolver] = None) -> None:
        self.resolver = resolver or ReferenceResolver()

    def analyze(
        self,
        message: str,
        mode: str,
        context: Optional[Dict[str, Any]] = None,
        session: Optional[Dict[str, Any]] = None,
        intent: Optional[str] = None,
    ) -> Situation:
        lower = message.lower().strip()
        resolved = self.resolver.resolve(message, context, session)
        inferred_intent = intent or self._intent(lower, context)
        likely_skill = self._likely_skill(lower, inferred_intent)
        context_available = resolved.target is not None or self._context_available(context)
        needs_context = resolved.surface_reference is not None or self._intent_needs_context(inferred_intent, lower)
        missing_reason = None
        if needs_context and not context_available:
            missing_reason = resolved.missing_reason or "No readable current Mac context is available."
        return Situation(
            mode=mode,
            intent=inferred_intent,
            user_goal=message.strip(),
            surface_reference=resolved.surface_reference,
            resolved_target=resolved.target,
            target_source=resolved.source,
            confidence=resolved.confidence if needs_context else max(resolved.confidence, 0.7),
            needs_context=needs_context,
            context_available=context_available,
            missing_context_reason=missing_reason,
            preferred_response_style=self._response_style(mode, inferred_intent),
            likely_skill=likely_skill,
        )

    def _intent(self, lower: str, context: Optional[Dict[str, Any]]) -> str:
        if lower.startswith("/learn") or any(phrase in lower for phrase in ["learn this", "make this a skill", "save this workflow", "remember how to do this", "next time automate this"]):
            return "skill_learning"
        if re.search(r"\b(time|what time is it|current time)\b", lower):
            return "time"
        if re.search(r"\b(date|what day is it|today'?s date)\b", lower):
            return "date"
        if lower.startswith(("open ", "launch ", "start ")):
            if "." in lower or "http" in lower or any(word in lower for word in ["website", "site", "url"]):
                return "open_url"
            return "open_app"
        if "screenshot" in lower or "screen shot" in lower:
            return "screenshot"
        if "joke" in lower:
            return "joke"
        if any(phrase in lower for phrase in ["system status", "battery", "cpu", "memory usage"]):
            return "system_status"
        if any(phrase in lower for phrase in ["say back", "draft a reply", "reply to", "email back"]):
            return "draft_reply"
        if "summar" in lower and (self._context_available(context) or any(word in lower for word in ["this", "page", "document", "file"])):
            return "summarize_context"
        if any(word in lower for word in ["rewrite", "polish", "make it better", "shorter", "less formal"]):
            return "rewrite_context"
        return "assistant"

    def _likely_skill(self, lower: str, intent: str) -> Optional[str]:
        mapping = {
            "time": "time.now",
            "date": "date.today",
            "open_app": "app.open",
            "open_url": "browser.open_url",
            "screenshot": "screenshot.take",
            "joke": "joke.tell",
            "system_status": "system.status",
            "skill_learning": "jarvis-learn-skill",
            "draft_reply": "email-draft-reply",
            "summarize_context": "document-summarize-current",
            "rewrite_context": "document-rewrite-selection",
        }
        if "reminder" in lower and any(word in lower for word in ["create", "add", "remind"]):
            return "reminder-create"
        return mapping.get(intent)

    def _context_available(self, context: Optional[Dict[str, Any]]) -> bool:
        if not context:
            return False
        browser = context.get("browser") or {}
        document = context.get("documentContext") or {}
        accessibility = context.get("accessibility") or {}
        return any(
            str(value or "").strip()
            for value in [
                context.get("selectedText"),
                context.get("surroundingText"),
                browser.get("selectedText"),
                browser.get("pageText"),
                document.get("selectedText"),
                document.get("currentParagraph"),
                document.get("textPreview"),
                accessibility.get("visibleText"),
            ]
        ) or bool(context.get("schedule"))

    def _intent_needs_context(self, intent: str, lower: str) -> bool:
        return intent in {"draft_reply", "summarize_context", "rewrite_context"} or any(
            term in lower for term in ["this", "here", "it", "that", "current", "selected"]
        )

    def _response_style(self, mode: str, intent: str) -> str:
        if mode == "dictation":
            return "insert_only"
        if intent == "skill_learning":
            return "approval_first"
        if intent in {"draft_reply", "rewrite_context"}:
            return "draft_review"
        return "short_natural"
