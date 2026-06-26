from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def capabilities(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.capability_registry.status()


@router.get("/status")
async def capability_status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.capability_registry.status()


@router.post("/explain")
async def explain(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    query = str(payload.get("query") or payload.get("message") or "What can you do?")
    mode = str(payload.get("mode") or "quick_assistant")
    context = payload.get("context") if isinstance(payload.get("context"), dict) else None
    answer = container.capability_registry.explain(query=query, mode=mode, active_context=context)
    return {"answer": answer}
