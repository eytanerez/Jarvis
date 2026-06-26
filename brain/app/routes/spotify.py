from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.spotify_service.status()


@router.post("/test")
async def test(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.spotify_service.test()


def _action(container: ServiceContainer, action_type: str, payload: dict, risk: str) -> dict:
    return container.spotify_service.build_action(action_type, payload or {}, risk=risk)


@router.post("/search")
async def search(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    spotify = container.spotify_service
    if not spotify.connected:
        return {"available": False, "reason": spotify.status()["reason"]}
    return {"available": True, "query": payload.get("query", ""), "results": []}


@router.post("/play")
async def play(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "play", payload, risk="yellow")


@router.post("/pause")
async def pause(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "pause", payload, risk="green")


@router.post("/next")
async def next_track(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "next", payload, risk="green")


@router.post("/previous")
async def previous_track(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "previous", payload, risk="green")


@router.post("/volume")
async def volume(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "volume", payload, risk="yellow")


@router.post("/devices")
async def devices(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    spotify = container.spotify_service
    if not spotify.connected:
        return {"available": False, "reason": spotify.status()["reason"]}
    return {"available": True, "devices": []}


@router.post("/playlist/create")
async def playlist_create(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "playlist_create", payload, risk="yellow")


@router.post("/playlist/add")
async def playlist_add(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "playlist_add", payload, risk="yellow")


@router.post("/save-track")
async def save_track(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return _action(container, "save_track", payload, risk="yellow")
