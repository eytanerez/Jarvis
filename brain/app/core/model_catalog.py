from __future__ import annotations

import json
import os
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

# Bundled defaults ship next to this module so a fresh checkout works with no
# external file. The catalog is intentionally *data*: provider model names,
# fallback chains, and stale-model remaps used to be Python constants, which
# turned every model-lineup change into a code change. Now they live here (or
# in the file pointed at by JARVIS_MODEL_CATALOG_PATH), refreshable at runtime
# via POST /runtime/models/reload.
_BUNDLED_CATALOG_PATH = Path(__file__).resolve().parent / "model_catalog.json"

_SINGLETON_LOCK = threading.Lock()
_SINGLETON: Optional["ModelCatalog"] = None


def get_model_catalog() -> "ModelCatalog":
    """Return the process-wide catalog, building it on first use."""
    global _SINGLETON
    with _SINGLETON_LOCK:
        if _SINGLETON is None:
            _SINGLETON = ModelCatalog()
        return _SINGLETON


class ModelCatalog:
    """Loads provider model defaults/fallbacks/aliases from JSON.

    Resolution order: the bundled ``model_catalog.json`` provides defaults; an
    optional external file (``JARVIS_MODEL_CATALOG_PATH``) is deep-merged on top
    so an operator can override just the keys they care about without copying the
    whole file. ``reload()`` re-reads both, so editing the file and hitting the
    runtime reload endpoint takes effect without restarting the brain.
    """

    def __init__(self, path: Optional[Path] = None) -> None:
        self._lock = threading.RLock()
        self._external_path = path
        self._data: Dict[str, Any] = {}
        self.reload()

    def reload(self) -> Dict[str, Any]:
        with self._lock:
            data = self._read_json(_BUNDLED_CATALOG_PATH) or {}
            external = self._read_json(self._external_path_resolved())
            if external:
                data = self._deep_merge(data, external)
            self._data = data
            return self.as_dict()

    def as_dict(self) -> Dict[str, Any]:
        with self._lock:
            return json.loads(json.dumps(self._data))

    # -- accessors -----------------------------------------------------------

    def default(self, provider: str, task_type: str) -> str:
        defaults = self._provider(provider).get("defaults") or {}
        tier = self._tier(task_type)
        value = defaults.get(tier) or defaults.get("fast")
        return str(value or "")

    def fallbacks(self, provider: str) -> List[str]:
        return [str(model) for model in (self._provider(provider).get("fallbacks") or [])]

    def aliases(self, provider: str) -> Dict[str, str]:
        raw = self._provider(provider).get("aliases") or {}
        return {str(key).strip().lower(): str(value) for key, value in raw.items()}

    def stale_models(self, provider: str) -> Set[str]:
        return {str(model).strip().lower() for model in (self._provider(provider).get("staleModels") or [])}

    def stale_replacement(self, provider: str) -> str:
        return str(self._provider(provider).get("staleReplacement") or "")

    # -- internals -----------------------------------------------------------

    def _provider(self, provider: str) -> Dict[str, Any]:
        with self._lock:
            value = self._data.get(provider)
            return value if isinstance(value, dict) else {}

    @staticmethod
    def _tier(task_type: str) -> str:
        return "smart" if task_type in {"smart", "reasoning"} else "fast"

    def _external_path_resolved(self) -> Optional[Path]:
        if self._external_path is not None:
            return self._external_path
        configured = os.environ.get("JARVIS_MODEL_CATALOG_PATH", "").strip()
        return Path(configured) if configured else None

    @staticmethod
    def _read_json(path: Optional[Path]) -> Optional[Dict[str, Any]]:
        if path is None or not path.exists():
            return None
        try:
            with path.open("r", encoding="utf-8") as handle:
                data = json.load(handle)
            return data if isinstance(data, dict) else None
        except (OSError, ValueError) as exc:
            print(f"[jarvis-brain] model catalog at {path} could not be read: {exc}", flush=True)
            return None

    @classmethod
    def _deep_merge(cls, base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
        merged = dict(base)
        for key, value in override.items():
            existing = merged.get(key)
            if isinstance(existing, dict) and isinstance(value, dict):
                merged[key] = cls._deep_merge(existing, value)
            else:
                merged[key] = value
        return merged
