from __future__ import annotations

from fastapi import APIRouter, Depends

from ..build_info import status_payload, version_payload
from ..core.service_container import ServiceContainer
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/version")
async def runtime_version() -> dict:
    """Single source of truth for what is running, for the version dashboard."""
    return version_payload()


@router.get("/status")
async def runtime_status(container: ServiceContainer = Depends(get_container)) -> dict:
    secrets = container.runtime_secrets
    payload = status_payload()
    payload.update(
        {
            "providerOrder": list(secrets.providerOrder),
            "keyPresence": secrets.key_presence(),
            "activeProvider": secrets.active_provider(),
        }
    )
    return payload


@router.get("/models")
async def runtime_models(container: ServiceContainer = Depends(get_container)) -> dict:
    """The provider model catalog (defaults, fallbacks, stale-model remaps).

    Backed by app/core/model_catalog.json so updating a model name is a config
    edit, not a code change. The Swift app can read this to show the live
    catalog and POST /runtime/models/reload to pick up edits without a restart.
    """
    return {"catalog": container.provider_manager.catalog.as_dict()}


@router.post("/models/reload")
async def runtime_models_reload(container: ServiceContainer = Depends(get_container)) -> dict:
    """Re-read the model catalog from disk (bundled + JARVIS_MODEL_CATALOG_PATH)."""
    return {"catalog": container.provider_manager.catalog.reload()}


@router.get("/dashboard")
async def runtime_dashboard(container: ServiceContainer = Depends(get_container)) -> dict:
    """Aggregated, non-blocking status for the performance dashboard (Priority 7).

    Reads only in-memory state and the lightweight file-index status. It never
    runs the F5-TTS subprocess probe or loads any model, so polling it stays
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
        {"name": "f5TTSWorker", "running": tts_snapshot.get("f5TTSWorkerRunning", False)},
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
