from __future__ import annotations

from collections import Counter
from typing import Any, Dict, List

from .availability import AvailabilityContext, resolve_availability
from .definitions import CATALOG
from .models import RISK_LEVELS, SOURCES


def run_self_test() -> Dict[str, Any]:
    """Validate the catalog's internal invariants. Returns issues + summary."""
    issues: List[str] = []

    # 1. Every skill name is unique (no shadowing across folders).
    name_counts = Counter(defn.name for defn in CATALOG)
    duplicate_names = sorted(name for name, count in name_counts.items() if count > 1)
    for name in duplicate_names:
        paths = [defn.path for defn in CATALOG if defn.name == name]
        issues.append(f"Duplicate skill name '{name}' across: {', '.join(paths)}")

    # 2. Every capability id is unique and matches category.skill-name.
    id_counts = Counter(defn.capability_id for defn in CATALOG)
    for cap_id, count in id_counts.items():
        if count > 1:
            issues.append(f"Duplicate capability id '{cap_id}'")

    # 3. risk_level and source are from the allowed sets.
    for defn in CATALOG:
        if defn.risk_level not in RISK_LEVELS:
            issues.append(f"{defn.path}: invalid risk_level '{defn.risk_level}'")
        if defn.source not in SOURCES:
            issues.append(f"{defn.path}: invalid source '{defn.source}'")
        # 4. yellow/red imply requires_confirmation; green implies not.
        if defn.risk_level in {"yellow", "red"} and not defn.requires_confirmation:
            issues.append(f"{defn.path}: {defn.risk_level} skill must require confirmation")
        if defn.risk_level == "green" and defn.requires_confirmation:
            issues.append(f"{defn.path}: green skill must not require confirmation")
        # 5. swift_action skills must name an executor.
        if defn.source == "swift_action" and not defn.executor:
            issues.append(f"{defn.path}: swift_action skill must declare an executor")
        # 6. spotify skills declare secrets but never values.
        if defn.source == "spotify_api" and not defn.required_secrets:
            issues.append(f"{defn.path}: spotify skill must declare required_secrets")

    # 7. With nothing wired, unwired sources must resolve unavailable.
    bare = AvailabilityContext()
    for defn in CATALOG:
        if defn.source in {"atoll_apple_bridge", "spotify_api"}:
            available, reason = resolve_availability(defn, bare)
            if available or not reason:
                issues.append(f"{defn.path}: should be unavailable with a reason when its bridge/API is not wired")

    return {
        "ok": not issues,
        "skillCount": len(CATALOG),
        "duplicateNames": duplicate_names,
        "issues": issues,
    }
