from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def list_scheduled_agents(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.scheduled_agent_service.list()


@router.get("/{agent_id}")
async def get_scheduled_agent(agent_id: str, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.scheduled_agent_service.get(agent_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Scheduled agent not found") from exc


@router.post("/{agent_id}")
async def update_scheduled_agent(agent_id: str, payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.scheduled_agent_service.update(agent_id, payload)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Scheduled agent not found") from exc


@router.post("/{agent_id}/preview")
async def preview_scheduled_agent(agent_id: str, payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.scheduled_agent_service.preview(agent_id, payload)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Scheduled agent not found") from exc


@router.post("/{agent_id}/record-run")
async def record_scheduled_agent_run(agent_id: str, payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.scheduled_agent_service.record_run(agent_id, payload.get("runAt"))
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Scheduled agent not found") from exc
