from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.post("/test")
async def providers_test(container: ServiceContainer = Depends(get_container)) -> dict:
    return await container.provider_manager.test()


@router.get("/diagnostics")
async def providers_diagnostics(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.provider_manager.diagnostics()
