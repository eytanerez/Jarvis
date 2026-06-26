from __future__ import annotations

from typing import Dict, List

from ..capabilities.capability import Capability
from .availability import AvailabilityContext, resolve_availability
from .definitions import CATALOG
from .models import SkillDef


def build_capability(defn: SkillDef, ctx: AvailabilityContext) -> Capability:
    available, status_reason = resolve_availability(defn, ctx)
    how_to = defn.how_to_use or _default_how_to(defn, available, status_reason)
    return Capability(
        id=defn.capability_id,
        name=defn.description,
        description=defn.description,
        category=defn.capability_category,
        examples=list(defn.examples),
        enabled=True,
        available=available,
        source=defn.source,
        required_permissions=defn.permissions(),
        required_connectors=list(defn.required_connectors),
        required_secrets=list(defn.required_secrets),
        allowed_modes=defn.modes(),
        risk_level=defn.risk_level,  # type: ignore[arg-type]
        requires_confirmation=defn.requires_confirmation,
        limitations=[],
        how_to_use=how_to,
        status_reason=status_reason,
    )


def catalog_capabilities(ctx: AvailabilityContext) -> List[Capability]:
    return [build_capability(defn, ctx) for defn in CATALOG]


def catalog_index() -> Dict[str, SkillDef]:
    """Map capability id -> SkillDef for cross-checking skills and capabilities."""
    return {defn.capability_id: defn for defn in CATALOG}


def _default_how_to(defn: SkillDef, available: bool, status_reason: str) -> str:
    base = f"Ask Jarvis to {defn.description[0].lower() + defn.description[1:]}."
    if not available and status_reason:
        return f"{base} Unavailable now: {status_reason}."
    return base
