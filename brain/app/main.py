from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, Header, HTTPException, Response

from .chat_service import ChatService
from .file_index import FileIndexService
from .schemas import (
    ChatRequest,
    FileIndexControlRequest,
    FileReadRequest,
    FileSearchRequest,
    FileSummarizeRequest,
    MemoryAddRequest,
    MemoryEditRequest,
    MemorySearchRequest,
    StructuredResponse,
    TTSRequest,
    WebSearchRequest,
)
from .security import token_is_valid
from .tts_service import TTSService
from .web_search import WebSearch

app = FastAPI(title="Jarvis Brain")
chat_service = ChatService()
tts_service = TTSService()
web = WebSearch()
file_index = FileIndexService()


def require_auth(x_jarvis_token: Optional[str]) -> None:
    if not token_is_valid(x_jarvis_token):
        raise HTTPException(status_code=401, detail="Invalid Jarvis token")


@app.get("/health")
async def health(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"ok": True}


@app.post("/chat", response_model=StructuredResponse)
async def chat(request: ChatRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return await chat_service.chat(
        request.message,
        request.context,
        request.session,
        request.mode,
        intent=request.intent,
        requires_screen_context=request.requiresScreenContext,
    )


@app.post("/memory/add", response_model=StructuredResponse)
async def memory_add(request: MemoryAddRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    chat_service.memory.add(request.text, request.metadata)
    return chat_service.response("Got it.", speak="Got it.")


@app.post("/memory/search")
async def memory_search(request: MemorySearchRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"results": chat_service.memory.search(request.query, request.limit)}


@app.get("/memory/list")
async def memory_list(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"results": chat_service.memory.list()}


@app.get("/memory/status")
async def memory_status(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return chat_service.memory.status()


@app.post("/memory/delete")
async def memory_delete(payload: dict, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"deleted": chat_service.memory.delete(str(payload.get("id", "")))}


@app.post("/memory/edit")
async def memory_edit(request: MemoryEditRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    edited = chat_service.memory.edit(request.id, text=request.text, metadata=request.metadata)
    if edited is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    return {"memory": edited}


@app.post("/providers/test")
async def providers_test(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return await chat_service.providers.test()


@app.get("/providers/diagnostics")
async def providers_diagnostics(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return chat_service.providers.diagnostics()


@app.get("/tts/status")
async def tts_status(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return tts_service.status()


@app.post("/tts/synthesize")
async def tts_synthesize(request: TTSRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> Response:
    require_auth(x_jarvis_token)
    try:
        wav = tts_service.synthesize(
            request.text,
            voice=request.voice,
            speed=request.speed,
            engine=request.engine,
            reference_audio_path=request.referenceAudioPath,
            exaggeration=request.exaggeration,
            cfg_weight=request.cfgWeight,
            style_preset=request.stylePreset,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return Response(content=wav, media_type="audio/wav")


@app.get("/settings")
async def settings(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"ok": True}


@app.post("/settings")
async def save_settings(payload: dict, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"ok": True, "received": payload}


@app.post("/web/search")
async def web_search(request: WebSearchRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {"results": web.search(request.query, request.limit)}


@app.post("/files/index/start")
async def files_index_start(request: Optional[FileIndexControlRequest] = None, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    request = request or FileIndexControlRequest()
    return file_index.start(folders=request.folders, exclusions=request.exclusions)


@app.post("/files/index/stop")
async def files_index_stop(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return file_index.stop()


@app.post("/files/index/reindex")
async def files_index_reindex(request: Optional[FileIndexControlRequest] = None, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    request = request or FileIndexControlRequest()
    return file_index.reindex(folders=request.folders, exclusions=request.exclusions)


@app.get("/files/index/status")
async def files_index_status(x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return file_index.status()


@app.post("/files/search")
async def files_search(request: FileSearchRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    return {
        "results": file_index.search(
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


@app.post("/files/read")
async def files_read(request: FileReadRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    try:
        return file_index.read(file_id=request.id, path=request.path, max_chars=request.maxChars)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@app.post("/files/summarize")
async def files_summarize(request: FileSummarizeRequest, x_jarvis_token: Optional[str] = Header(default=None)) -> dict:
    require_auth(x_jarvis_token)
    try:
        return file_index.summarize(file_id=request.id, path=request.path, max_chars=request.maxChars)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
