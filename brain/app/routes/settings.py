from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from ..schemas import PerformanceModeRequest
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def get_settings(container: ServiceContainer = Depends(get_container)) -> dict:
    return {
        "ok": True,
        "performance": container.performance.to_dict(),
        "prompts": container.prompt_service.list(editable_only=True)["prompts"],
    }


@router.post("")
async def save_settings(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return {"ok": True, "received": payload}


@router.get("/prompts")
async def get_prompts(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.prompt_service.list(editable_only=True)


@router.get("/prompts/{prompt_id}")
async def get_prompt(prompt_id: str, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.prompt_service.get(prompt_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Prompt not found") from exc


@router.post("/prompts")
async def save_prompts(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    prompts = payload.get("prompts")
    if not isinstance(prompts, list):
        raise HTTPException(status_code=400, detail="Expected prompts list")
    try:
        return container.prompt_service.save_many(prompts)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/prompts/{prompt_id}")
async def save_prompt(prompt_id: str, payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.prompt_service.save(prompt_id, str(payload.get("content") or ""))
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Prompt not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/prompts/{prompt_id}/reset")
async def reset_prompt(prompt_id: str, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.prompt_service.reset(prompt_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Prompt not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


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
