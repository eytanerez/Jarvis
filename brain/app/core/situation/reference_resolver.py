from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


REFERENCE_TERMS = (
    "this",
    "here",
    "it",
    "that",
    "this page",
    "this email",
    "this message",
    "this paragraph",
    "the last thing",
    "reply to him",
    "reply to her",
    "make it",
    "do that again",
)


@dataclass
class ResolvedReference:
    surface_reference: Optional[str]
    target: Optional[str]
    source: Optional[str]
    confidence: float
    missing_reason: Optional[str] = None


class ReferenceResolver:
    def resolve(
        self,
        message: str,
        context: Optional[Dict[str, Any]],
        session: Optional[Dict[str, Any]] = None,
    ) -> ResolvedReference:
        lower = message.lower()
        surface = self._surface_reference(lower)
        context = context or {}
        session = session or {}

        selected = self._first_text(
            context.get("selectedText"),
            (context.get("documentContext") or {}).get("selectedText"),
            (context.get("browser") or {}).get("selectedText"),
        )
        if selected:
            return ResolvedReference(surface, selected, "selected_text", 0.95)

        document = context.get("documentContext") or {}
        document_text = self._first_text(
            document.get("currentParagraph"),
            document.get("textPreview"),
            context.get("surroundingText"),
        )
        if document_text and self._looks_document_target(lower, document):
            return ResolvedReference(surface, document_text, "document_context", 0.85)

        accessibility = context.get("accessibility") or {}
        visible = self._first_text(accessibility.get("visibleText"))
        if visible and not self._looks_browser_target(lower):
            return ResolvedReference(surface, visible, "visible_app_context", 0.72)

        browser = context.get("browser") or {}
        browser_text = self._first_text(browser.get("pageText"), browser.get("title"), browser.get("url"))
        if browser_text and (surface or self._looks_browser_target(lower)):
            return ResolvedReference(surface, browser_text, "browser_context", 0.82)

        email_text = self._first_text(
            (context.get("email") or {}).get("threadText"),
            (context.get("message") or {}).get("visibleText"),
        )
        if email_text and self._looks_reply_target(lower):
            return ResolvedReference(surface, email_text, "message_context", 0.84)

        last_target = self._first_text(
            session.get("lastResolvedTarget"),
            session.get("lastSelectedText"),
            session.get("lastAssistantResult"),
        )
        if last_target and (surface or self._looks_follow_up(lower)):
            return ResolvedReference(surface, last_target, "working_context", 0.65)

        if surface:
            return ResolvedReference(surface, None, None, 0.0, "No selected, document, browser, message, or recent target context is available.")
        return ResolvedReference(None, None, None, 0.0)

    def has_reference(self, message: str) -> bool:
        return self._surface_reference(message.lower()) is not None

    def _surface_reference(self, lower: str) -> Optional[str]:
        for term in sorted(REFERENCE_TERMS, key=len, reverse=True):
            if term in lower:
                return term
        return None

    def _first_text(self, *values: Any) -> Optional[str]:
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if text:
                return text
        return None

    def _looks_document_target(self, lower: str, document: Dict[str, Any]) -> bool:
        app = str(document.get("appName") or "").lower()
        if any(word in app for word in ["word", "docs", "textedit", "pages"]):
            return True
        return any(word in lower for word in ["document", "paragraph", "selection", "rewrite", "summarize this", "here"])

    def _looks_browser_target(self, lower: str) -> bool:
        return any(word in lower for word in ["page", "website", "site", "article", "browser", "tab"])

    def _looks_reply_target(self, lower: str) -> bool:
        return any(phrase in lower for phrase in ["say back", "reply", "respond", "message back", "email back"])

    def _looks_follow_up(self, lower: str) -> bool:
        return any(phrase in lower for phrase in ["make it", "shorter", "less formal", "more direct", "second one", "send that", "save this"])
