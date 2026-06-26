from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from ..schemas import (
    MemoryAddRequest,
    MemoryEditRequest,
    MemorySearchRequest,
    StructuredResponse,
)
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.post("/add", response_model=StructuredResponse)
async def memory_add(request: MemoryAddRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    container.memory_service.add(request.text, request.metadata)
    return container.chat_service.response("Got it.", speak="Got it.")


@router.post("/search")
async def memory_search(request: MemorySearchRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    return {"results": container.memory_service.search(request.query, request.limit)}


@router.get("/list")
async def memory_list(container: ServiceContainer = Depends(get_container)) -> dict:
    return {"results": container.memory_service.list()}


@router.get("/status")
async def memory_status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.memory_service.status()


@router.post("/delete")
async def memory_delete(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return {"deleted": container.memory_service.delete(str(payload.get("id", "")))}


@router.post("/edit")
async def memory_edit(request: MemoryEditRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    edited = container.memory_service.edit(request.id, text=request.text, metadata=request.metadata)
    if edited is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    return {"memory": edited}
