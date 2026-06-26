from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.dictation_service.status()


@router.post("/transcribe")
async def transcribe(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.dictation_service.transcribe(audio=payload.get("audio"), text=payload.get("text"))


@router.post("/clean")
async def clean(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.dictation_service.clean(payload.get("text", ""))


@router.post("/format")
async def format_dictation(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.dictation_service.format(payload.get("text", ""), active_app=payload.get("activeApp"))


@router.post("/insert-result")
async def insert_result(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.dictation_service.insert_result(payload.get("text", ""))
