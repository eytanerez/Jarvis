from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from ..schemas import WebSearchRequest
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.post("/search")
async def web_search(request: WebSearchRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    return {"results": container.web_search.search(request.query, request.limit)}
