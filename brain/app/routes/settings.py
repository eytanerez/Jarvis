from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from ..schemas import PerformanceModeRequest
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def get_settings(container: ServiceContainer = Depends(get_container)) -> dict:
    return {"ok": True, "performance": container.performance.to_dict()}


@router.post("")
async def save_settings(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return {"ok": True, "received": payload}


@router.get("/performance")
async def get_performance(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.performance.to_dict()


@router.post("/performance")
async def set_performance(
    request: PerformanceModeRequest,
    container: ServiceContainer = Depends(get_container),
) -> dict:
    try:
        container.performance.set_mode(request.mode)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    # Keep the shared file index aligned with the new mode's policy.
    file_index = container.file_index_service
    file_index.set_mode(container.performance.file_index_default_mode)
    if file_index.mode == "off":
        file_index.stop()
    return container.performance.to_dict()
