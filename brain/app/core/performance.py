from __future__ import annotations

import json
import os
import threading
from pathlib import Path
from typing import Any, Dict, Optional

PERFORMANCE = "performance"
BALANCED = "balanced"
FULL_CONTEXT = "full_context"
VALID_PERFORMANCE_MODES = (PERFORMANCE, BALANCED, FULL_CONTEXT)

# Performance mode -> default file-index mode. Background full reindex loops are
# never used in any mode (Priority 1/6): the strongest option is incremental
# scans inside approved folders.
_FILE_INDEX_DEFAULT = {
    PERFORMANCE: "off",
    BALANCED: "manual",
    FULL_CONTEXT: "incremental",
}


class PerformanceSettings:
    """Single source of truth for the active performance mode.

    The mode is persisted to brain home so it survives restarts, and can be
    overridden for a launch with ``JARVIS_PERFORMANCE_MODE``. The class exposes
    the concrete toggles each mode implies so the rest of the brain never has to
    re-derive the policy (which engine may preload, whether memory suggestions
    are allowed, what the default file-index mode is, ...).
    """

    def __init__(self, home: Optional[Path] = None) -> None:
        self.home = home or Path(
            os.environ.get("JARVIS_BRAIN_HOME", Path.home() / "Library/Application Support/JarvisNotch")
        )
        self.home.mkdir(parents=True, exist_ok=True)
        self.path = self.home / "performance.json"
        self._lock = threading.RLock()
        self._mode = self._load_mode()

    def _load_mode(self) -> str:
        env = os.environ.get("JARVIS_PERFORMANCE_MODE", "").strip().lower()
        if env in VALID_PERFORMANCE_MODES:
            return env
        if self.path.exists():
            try:
                data = json.loads(self.path.read_text(encoding="utf-8"))
                mode = str(data.get("mode", "")).strip().lower()
                if mode in VALID_PERFORMANCE_MODES:
                    return mode
            except Exception:
                pass
        return BALANCED

    @property
    def mode(self) -> str:
        with self._lock:
            return self._mode

    def set_mode(self, mode: str) -> str:
        normalized = (mode or "").strip().lower()
        if normalized not in VALID_PERFORMANCE_MODES:
            raise ValueError(f"Unknown performance mode: {mode!r}")
        with self._lock:
            self._mode = normalized
            try:
                self.path.write_text(json.dumps({"mode": normalized}, indent=2), encoding="utf-8")
            except Exception:
                pass
        return normalized

    # -- Derived policy ----------------------------------------------------

    @property
    def file_index_default_mode(self) -> str:
        return _FILE_INDEX_DEFAULT[self.mode]

    @property
    def background_full_indexing(self) -> bool:
        # No mode ever runs full background reindex loops.
        return False

    @property
    def f5_tts_preload(self) -> bool:
        # F5-TTS is only ever loaded on demand, never preloaded.
        return False

    @property
    def memory_suggestions(self) -> bool:
        return self.mode != PERFORMANCE

    @property
    def screenshot_fallback(self) -> bool:
        return self.mode != PERFORMANCE

    @property
    def shortest_spoken_responses(self) -> bool:
        return self.mode == PERFORMANCE

    @property
    def richer_context_packs(self) -> bool:
        return self.mode == FULL_CONTEXT

    def toggles(self) -> Dict[str, Any]:
        return {
            "fileIndexDefaultMode": self.file_index_default_mode,
            "backgroundFullIndexing": self.background_full_indexing,
            "f5TTSPreload": self.f5_tts_preload,
            "memorySuggestions": self.memory_suggestions,
            "screenshotFallback": self.screenshot_fallback,
            "shortestSpokenResponses": self.shortest_spoken_responses,
            "richerContextPacks": self.richer_context_packs,
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "mode": self.mode,
            "availableModes": list(VALID_PERFORMANCE_MODES),
            "toggles": self.toggles(),
        }
