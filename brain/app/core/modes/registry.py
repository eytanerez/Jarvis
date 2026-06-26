from __future__ import annotations

from typing import Dict, Iterable, Optional

from .mode import AssistantMode
from .presets import default_modes


class ModeRegistry:
    def __init__(self, modes: Optional[Iterable[AssistantMode]] = None) -> None:
        source = {mode.id: mode for mode in modes} if modes is not None else default_modes()
        self._modes: Dict[str, AssistantMode] = dict(source)

    def list(self) -> list[dict]:
        return [mode.to_dict() for mode in self._modes.values()]

    def get(self, mode_id: Optional[str]) -> AssistantMode:
        normalized = self.normalize_id(mode_id)
        return self._modes.get(normalized) or self._modes["quick_assistant"]

    def normalize_id(self, mode_id: Optional[str]) -> str:
        value = (mode_id or "").strip().lower()
        aliases = {
            "": "quick_assistant",
            "normal": "quick_assistant",
            "fast": "quick_assistant",
            "smart": "deep_research",
            "reasoning": "deep_research",
            "assistant": "quick_assistant",
            "email": "email_writer",
            "document": "document_editor",
            "learn": "skill_learning",
        }
        return aliases.get(value, value)

    def register(self, mode: AssistantMode) -> None:
        self._modes[mode.id] = mode
