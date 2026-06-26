from __future__ import annotations

import os
from typing import Any, Dict, Optional

from .core.apple_bridge import APPLE_BRIDGE_AREAS, default_area_status


class AtollBridge:
    """Tracks per-area availability of the Atoll / Apple bridge.

    Each area is wired independently. Real wiring happens on the Swift/Atoll
    side; this service reflects what is connected so capabilities are honest.
    Areas default to unavailable. They can be turned on per area with env vars
    like ``JARVIS_ATOLL_CALENDAR=rw`` (values: off | read | write | rw/full),
    or programmatically via :meth:`set_area` (used by tests and the Mac app).
    """

    def __init__(self, environ: Optional[Dict[str, str]] = None) -> None:
        env = os.environ if environ is None else environ
        self._areas: Dict[str, Dict[str, Any]] = {}
        for key, area in APPLE_BRIDGE_AREAS.items():
            self._areas[key] = default_area_status(area)
            self._apply_env(key, env.get(f"JARVIS_ATOLL_{key.upper()}", ""))

    def _apply_env(self, key: str, raw: str) -> None:
        mode = (raw or "").strip().lower()
        if not mode or mode in {"off", "0", "false", "no"}:
            return
        read = True
        write = mode in {"write", "rw", "readwrite", "full", "1", "true", "yes"}
        self.set_area(key, available=True, read=read, write=write)

    def set_area(
        self,
        key: str,
        *,
        available: bool,
        read: bool = True,
        write: bool = False,
        reason: str = "",
    ) -> Dict[str, Any]:
        area = APPLE_BRIDGE_AREAS.get(key)
        if area is None:
            raise KeyError(key)
        # An area that cannot support writes never reports write access.
        write = write and area.supports_write
        status = {
            "available": bool(available),
            "read": bool(available and read),
            "write": bool(available and write),
            "label": area.label,
            "reason": "" if available else (reason or area.offline_reason),
        }
        self._areas[key] = status
        return status

    def area(self, key: str) -> Dict[str, Any]:
        return dict(self._areas.get(key, {}))

    def status(self) -> Dict[str, Dict[str, Any]]:
        return {key: dict(value) for key, value in self._areas.items()}

    def summary(self) -> Dict[str, Any]:
        connected = sorted(key for key, value in self._areas.items() if value.get("available"))
        return {
            "connected": connected,
            "areas": self.status(),
            "anyConnected": bool(connected),
        }
