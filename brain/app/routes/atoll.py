from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.atoll_bridge.summary()


@router.get("/{area}")
async def area_status(area: str, container: ServiceContainer = Depends(get_container)) -> dict:
    info = container.atoll_bridge.area(area)
    if not info:
        raise HTTPException(status_code=404, detail="Unknown Atoll bridge area.")
    return info


@router.post("/{area}")
async def set_area(area: str, payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    """Let the Swift/Atoll side report which areas it has wired."""
    try:
        return container.atoll_bridge.set_area(
            area,
            available=bool(payload.get("available", False)),
            read=bool(payload.get("read", True)),
            write=bool(payload.get("write", False)),
            reason=str(payload.get("reason", "")),
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Unknown Atoll bridge area.") from exc
