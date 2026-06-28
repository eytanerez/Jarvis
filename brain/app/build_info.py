from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

# Generated constants (scripts/generate_build_info.sh). Fall back to safe
# defaults so the brain still runs before the generator has ever been invoked.
try:
    from ._build_constants import (  # type: ignore
        APP_VERSION,
        BRAIN_VERSION,
        BUILD_DATE,
        BUILD_NUMBER,
        GIT_COMMIT,
        UPDATE_CHANNEL,
    )
except Exception:  # pragma: no cover - only when constants were never generated
    APP_VERSION = "0.0.0"
    BUILD_NUMBER = "0"
    GIT_COMMIT = "unknown"
    BRAIN_VERSION = "0.0.0"
    UPDATE_CHANNEL = "dev"
    BUILD_DATE = ""


def _env(*names: str) -> Optional[str]:
    for name in names:
        value = os.environ.get(name)
        if value and value.strip():
            return value.strip()
    return None


def detect_brain_mode() -> str:
    """Bundled when running from inside Jarvis.app, otherwise developer."""
    override = _env("JARVIS_BRAIN_MODE")
    if override in {"bundled", "developer"}:
        return override
    path = str(Path(__file__).resolve())
    if ".app/Contents/Resources/brain" in path or "/Jarvis.app/" in path:
        return "bundled"
    return "developer"


def brain_path() -> str:
    # The brain root is the parent of this `app` package.
    return str(Path(__file__).resolve().parent.parent)


def version_payload() -> Dict[str, Any]:
    """What is actually running. App-side values come from the launching app
    (env) when present so the brain reports the real installed build, not just
    its own compiled constants."""
    return {
        "appVersion": _env("JARVIS_APP_VERSION") or APP_VERSION,
        "buildNumber": _env("JARVIS_APP_BUILD", "JARVIS_APP_BUILD_NUMBER") or BUILD_NUMBER,
        "gitCommit": _env("JARVIS_APP_COMMIT") or GIT_COMMIT,
        "brainVersion": BRAIN_VERSION,
        "updateChannel": _env("JARVIS_APP_CHANNEL", "JARVIS_UPDATE_CHANNEL") or UPDATE_CHANNEL,
        "buildDate": BUILD_DATE,
    }


def brain_runtime() -> Dict[str, Any]:
    mode = detect_brain_mode()
    app_version = _env("JARVIS_APP_VERSION")
    matches: Optional[bool]
    if app_version is None:
        matches = None  # unknown: no app version was provided to the brain
    else:
        matches = app_version == BRAIN_VERSION
    return {
        "brainMode": mode,
        "brainPath": brain_path(),
        "brainVersion": BRAIN_VERSION,
        "brainGitCommit": GIT_COMMIT,
        "buildNumber": BUILD_NUMBER,
        "buildDate": BUILD_DATE,
        "appVersion": app_version,
        "matchesAppVersion": matches,
    }


def status_payload() -> Dict[str, Any]:
    runtime = brain_runtime()
    warnings = []
    if runtime["matchesAppVersion"] is False:
        warnings.append(
            f"App version {runtime['appVersion']} does not match brain version {runtime['brainVersion']}. "
            "Production builds should use the bundled brain."
        )
    if runtime["brainMode"] == "developer" and _env("JARVIS_APP_VERSION"):
        warnings.append("Developer Brain Active: using a repo brain path instead of the bundled brain.")
    return {
        "version": version_payload(),
        "brain": runtime,
        "warnings": warnings,
    }
