from __future__ import annotations

from fastapi import APIRouter, Depends

from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def runtime_status(container: ServiceContainer = Depends(get_container)) -> dict:
    secrets = container.runtime_secrets
    return {
        "providerOrder": list(secrets.providerOrder),
        "keyPresence": secrets.key_presence(),
        "activeProvider": secrets.active_provider(),
    }


@router.get("/dashboard")
async def runtime_dashboard(container: ServiceContainer = Depends(get_container)) -> dict:
    """Aggregated, non-blocking status for the performance dashboard (Priority 7).

    Reads only in-memory state and the lightweight file-index status. It never
    runs the Chatterbox subprocess probe or loads any model, so polling it stays
    cheap while idle Jarvis stays quiet.
    """
    performance = container.performance
    file_index = container.file_index_service
    fi_status = file_index.status()
    tts = container.tts_service
    tts_snapshot = tts.runtime_snapshot()
    providers = container.provider_manager
    chat = container.chat_service

    latency_by_provider = providers.latency_by_provider()
    background_services = [
        {"name": "fileIndexWatcher", "running": bool(fi_status.get("watching"))},
        {"name": "fileIndexScan", "running": bool(fi_status.get("currentlyIndexing"))},
        {"name": "ttsIdleReaper", "running": tts.reaper_running()},
        {"name": "chatterboxWorker", "running": tts_snapshot.get("chatterboxWorkerRunning", False)},
    ]

    return {
        "brainRunning": True,
        "performanceMode": performance.mode,
        "performanceToggles": performance.toggles(),
        "fileIndex": {
            "mode": fi_status.get("indexingMode"),
            "currentlyIndexing": fi_status.get("currentlyIndexing"),
            "currentFile": fi_status.get("currentFile"),
            "fileCount": fi_status.get("fileCount"),
            "filesScannedThisRun": fi_status.get("filesScannedThisRun"),
            "filesSkippedThisRun": fi_status.get("filesSkippedThisRun"),
            "watching": fi_status.get("watching"),
            "lastFullReindexAt": fi_status.get("lastFullReindexAt"),
            "lastIncrementalScanAt": fi_status.get("lastIncrementalScanAt"),
        },
        "tts": tts_snapshot,
        "providers": {
            "lastModelUsed": providers.last_model_used(),
            "lastLatencyMs": providers.last_latency_ms(),
            "lastGeminiLatencyMs": latency_by_provider.get("gemini"),
            "latencyByProvider": latency_by_provider,
        },
        "chat": {
            "lastRoute": chat.last_route,
            "lastContextPackSize": chat.last_context_pack_size,
        },
        "backgroundServices": background_services,
    }
