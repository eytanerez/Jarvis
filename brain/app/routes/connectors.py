from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def connectors_status(container: ServiceContainer = Depends(get_container)) -> dict:
    """Report which connectors are wired up.

    The dedicated connector routers (calendar, email, messages, whatsapp) are
    scaffolding for upcoming work and are intentionally not enabled yet — this
    optimization pass does not add new features.
    """
    return {
        "connectors": [
            {"id": "calendar", "enabled": False},
            {"id": "email", "enabled": False},
            {"id": "messages", "enabled": False},
            {"id": "whatsapp", "enabled": False},
        ]
    }
