from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from ..core.service_container import ServiceContainer
from ..schemas import (
    FileIndexControlRequest,
    FileReadRequest,
    FileSearchRequest,
    FileSummarizeRequest,
)
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.post("/index/start")
async def files_index_start(
    request: Optional[FileIndexControlRequest] = None,
    container: ServiceContainer = Depends(get_container),
) -> dict:
    request = request or FileIndexControlRequest()
    return container.file_index_service.start(
        mode=request.mode, folders=request.folders, exclusions=request.exclusions
    )


@router.post("/index/stop")
async def files_index_stop(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.file_index_service.stop()


@router.post("/index/cancel")
async def files_index_cancel(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.file_index_service.cancel()


@router.post("/index/reindex")
async def files_index_reindex(
    request: Optional[FileIndexControlRequest] = None,
    container: ServiceContainer = Depends(get_container),
) -> dict:
    request = request or FileIndexControlRequest()
    return container.file_index_service.reindex(folders=request.folders, exclusions=request.exclusions)


@router.post("/index/incremental")
async def files_index_incremental(
    request: Optional[FileIndexControlRequest] = None,
    container: ServiceContainer = Depends(get_container),
) -> dict:
    request = request or FileIndexControlRequest()
    return container.file_index_service.incremental_scan(folders=request.folders, exclusions=request.exclusions)


@router.get("/index/status")
async def files_index_status(container: ServiceContainer = Depends(get_container)) -> dict:
    return container.file_index_service.status()


@router.post("/search")
async def files_search(request: FileSearchRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    return {
        "results": container.file_index_service.search(
            query=request.query,
            limit=request.limit,
            folders=request.folders,
            extensions=request.extensions,
            modified_after=request.modifiedAfter,
            modified_before=request.modifiedBefore,
            created_after=request.createdAfter,
            created_before=request.createdBefore,
        )
    }


@router.post("/read")
async def files_read(request: FileReadRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.file_index_service.read(file_id=request.id, path=request.path, max_chars=request.maxChars)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/summarize")
async def files_summarize(request: FileSummarizeRequest, container: ServiceContainer = Depends(get_container)) -> dict:
    try:
        return container.file_index_service.summarize(file_id=request.id, path=request.path, max_chars=request.maxChars)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
