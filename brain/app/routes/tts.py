from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response

from ..core.service_container import ServiceContainer
from ..schemas import TTSRequest
from .deps import get_container, require_auth

router = APIRouter(dependencies=[Depends(require_auth)])


@router.get("/status")
async def tts_status(
    forceRefresh: bool = False,
    container: ServiceContainer = Depends(get_container),
) -> dict:
    # Fast and non-blocking by default: the F5-TTS subprocess probe is cached
    # and only re-run when ``forceRefresh`` is requested (manual debug refresh).
    return container.tts_service.status(force_refresh=forceRefresh)


@router.post("/synthesize")
async def tts_synthesize(request: TTSRequest, container: ServiceContainer = Depends(get_container)) -> Response:
    try:
        wav = container.tts_service.synthesize(
            request.text,
            voice=request.voice,
            speed=request.speed,
            engine=request.engine,
            reference_audio_path=request.referenceAudioPath,
            reference_text=request.referenceText,
            cfg_strength=request.cfgStrength,
            nfe_step=request.nfeStep,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return Response(content=wav, media_type="audio/wav")
