from __future__ import annotations

from typing import Any, Dict, Optional

from ..core.prompts import PromptService
from .cleanup import DictationCleanup
from .formatter import DictationFormatter


class DictationService:
    def __init__(self, prompts: Optional[PromptService] = None) -> None:
        self.prompts = prompts or PromptService()
        self.cleanup = DictationCleanup()
        self.formatter = DictationFormatter()
        self._status = {
            "available": True,
            "recording": False,
            "sttEngines": ["apple", "whisper", "parakeet", "deepgram"],
            "postProcessing": ["off", "gemini", "ollama"],
        }

    def status(self) -> Dict[str, Any]:
        return dict(self._status)

    def transcribe(self, audio: Optional[str] = None, text: Optional[str] = None) -> Dict[str, Any]:
        # Swift currently owns Apple Speech transcription. This endpoint accepts
        # pre-transcribed text so the rest of the pipeline is testable now.
        transcript = (text or "").strip()
        return {"transcript": transcript, "engine": "apple" if transcript else "none"}

    def clean(self, text: str) -> Dict[str, Any]:
        return {
            "text": self.cleanup.clean(text),
            "prompt": self.prompts.content("dictation"),
        }

    def format(self, text: str, active_app: Optional[str] = None) -> Dict[str, Any]:
        prompt_id = "email" if "mail" in (active_app or "").lower() or "gmail" in (active_app or "").lower() or "outlook" in (active_app or "").lower() else "writing_style"
        return {
            "text": self.formatter.format(text, active_app=active_app),
            "activeApp": active_app,
            "prompt": self.prompts.content(prompt_id),
        }

    def insert_result(self, text: str) -> Dict[str, Any]:
        return {
            "answer": "Dictation ready to insert.",
            "speak": "",
            "actions": [{"id": "insert_dictation", "type": "insert_text", "payload": {"text": text}}],
            "metadata": {"route": "dictation", "modelRoute": "local_skill"},
        }
