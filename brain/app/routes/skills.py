from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("")
async def list_skills(container: ServiceContainer = Depends(get_container)) -> dict:
    manager = container.skill_manager
    return {
        "skills": manager.list(),
        "config": manager.config(),
        "warnings": manager.duplicate_warnings(),
    }


@router.get("/self-test")
async def skills_self_test(container: ServiceContainer = Depends(get_container)) -> dict:
    from ..core.catalog import run_self_test

    result = run_self_test()
    result["duplicateWarnings"] = container.skill_manager.duplicate_warnings()
    return result


@router.get("/bundles")
async def list_bundles(container: ServiceContainer = Depends(get_container)) -> dict:
    return {"bundles": container.skill_manager.bundles.list()}


@router.get("/history")
async def skill_run_history(limit: int = Query(default=50, ge=1, le=200), container: ServiceContainer = Depends(get_container)) -> dict:
    return container.skill_manager.list_history(limit=limit)


@router.post("/bundles")
async def save_bundle(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.skill_manager.bundles.save(payload)


@router.post("/bundles/run")
async def run_bundle(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.prepare_bundle(
            payload.get("name", ""),
            query=payload.get("query", ""),
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Skill bundle not found.") from exc


@router.get("/pending")
async def pending(container: ServiceContainer = Depends(get_container)) -> dict:
    return {"changes": container.skill_manager.approval.pending()}


@router.get("/pending/{change_id}/diff")
async def pending_diff(change_id: str, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.approval.diff(change_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Pending skill change not found.") from exc


@router.get("/{name}")
async def view_skill(
    name: str,
    path: Optional[str] = Query(default=None),
    container: ServiceContainer = Depends(get_container),
) -> dict:
    try:
        return container.skill_manager.view(name, path)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Skill not found.") from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Skill file not found.") from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/search")
async def search(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return {
        "skills": container.skill_manager.search(
            payload.get("query", ""),
            mode=payload.get("mode", "quick_assistant"),
        )
    }


@router.post("/run")
async def run_skill(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.run(payload.get("name", ""), inputs=payload.get("inputs") or payload.get("context") or {})
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Skill not found.") from exc


@router.post("/learn")
async def learn(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    source = payload.get("source") or payload.get("text") or payload.get("notes") or ""
    if not str(source).strip():
        raise HTTPException(status_code=400, detail="Skill learning needs source text, notes, or workflow description.")
    return container.skill_manager.learn(
        str(source),
        name=payload.get("name"),
        category=payload.get("category", "personal"),
        description=payload.get("description"),
        mode=payload.get("mode", "quick_assistant"),
    )


@router.post("/stage")
async def stage(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    return container.skill_manager.learn(
        str(payload.get("content") or payload.get("source") or ""),
        name=payload.get("name"),
        category=payload.get("category", "personal"),
        description=payload.get("description"),
        mode=payload.get("mode", "quick_assistant"),
    )


@router.post("/approve")
async def approve(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.approve(payload.get("id", ""))
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Pending skill change not found.") from exc


@router.post("/reject")
async def reject(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.reject(payload.get("id", ""))
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Pending skill change not found.") from exc


@router.post("/delete")
async def stage_delete_skill(payload: dict, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.delete(str(payload.get("name", "")))
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Skill not found.") from exc


@router.delete("/{name}")
async def delete_skill(name: str, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.skill_manager.delete(name)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Skill not found.") from exc
