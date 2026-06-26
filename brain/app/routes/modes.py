from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def list_modes(container: ServiceContainer = Depends(get_container)) -> dict:
    return {"modes": container.mode_registry.list(), "defaultMode": "quick_assistant"}


@router.get("/{mode_id}")
async def get_mode(mode_id: str, container: ServiceContainer = Depends(get_container)) -> dict:
    mode = container.mode_registry.get(mode_id)
    if mode.id != container.mode_registry.normalize_id(mode_id):
        raise HTTPException(status_code=404, detail="Mode not found")
    return mode.to_dict()
