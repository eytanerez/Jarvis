from __future__ import annotations

import hmac
import os
from typing import Optional


def _allow_insecure() -> bool:
    return os.environ.get("JARVIS_BRAIN_ALLOW_INSECURE", "").strip().lower() in {"1", "true", "yes"}


def token_is_valid(value: Optional[str]) -> bool:
    """Validate the per-launch brain token.

    Fail-closed: if no token is configured we deny every request rather than
    waving them through. The Swift app always sets ``JARVIS_BRAIN_TOKEN`` when it
    spawns the brain, so an unset token means a misconfiguration (or someone
    running the server by hand) — not a reason to drop authentication on a local
    HTTP API. For local development/tests, set ``JARVIS_BRAIN_ALLOW_INSECURE=1``
    to explicitly opt out.
    """
    expected = os.environ.get("JARVIS_BRAIN_TOKEN")
    if not expected:
        if _allow_insecure():
            return True
        print(
            "[jarvis-brain] JARVIS_BRAIN_TOKEN is not set; denying request. "
            "Set JARVIS_BRAIN_ALLOW_INSECURE=1 to allow unauthenticated local access.",
            flush=True,
        )
        return False
    if value is None:
        return False
    # Constant-time comparison to avoid leaking the token via timing.
    return hmac.compare_digest(value, expected)
