from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from ..schemas import ChatRequest, StructuredResponse
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.post("", response_model=StructuredResponse)
async def chat(request: ChatRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    return await container.chat_service.chat(
        request.message,
        request.context,
        request.session,
        request.mode,
        intent=request.intent,
        requires_screen_context=request.requiresScreenContext,
    )
