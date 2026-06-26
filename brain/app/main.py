from __future__ import annotations

from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException

from .core.service_container import ServiceContainer
from .routes import (
    atoll,
    capabilities,
    chat,
    connectors,
    dictation,
    files,
    memory,
    modes,
    providers,
    runtime,
    scheduled_agents,
    settings,
    skills,
    spotify,
    tts,
    web,
)
from .security import token_is_valid

app = FastAPI(title="Jarvis Brain")

# One shared container for the whole app. Building it is cheap — heavy services
# (TTS models, F5-TTS, file scans, memory embeddings) are created lazily on
# first use, so app launch and /health stay light.
container = ServiceContainer()
app.state.container = container


def require_auth(x_jarvis_token: Optional[str] = Header(default=None)) -> None:
    if not token_is_valid(x_jarvis_token):
        raise HTTPException(status_code=401, detail="Invalid Jarvis token")


@app.get("/health")
async def health(_: None = Depends(require_auth)) -> dict:
    # Intentionally trivial: never loads TTS models, F5-TTS, file index
    # scans, or memory embeddings.
    return {"ok": True}


app.include_router(chat.router, prefix="/chat", tags=["chat"])
app.include_router(memory.router, prefix="/memory", tags=["memory"])
app.include_router(modes.router, prefix="/modes", tags=["modes"])
app.include_router(providers.router, prefix="/providers", tags=["providers"])
app.include_router(tts.router, prefix="/tts", tags=["tts"])
app.include_router(settings.router, prefix="/settings", tags=["settings"])
app.include_router(runtime.router, prefix="/runtime", tags=["runtime"])
app.include_router(scheduled_agents.router, prefix="/scheduled-agents", tags=["scheduled-agents"])
app.include_router(files.router, prefix="/files", tags=["files"])
app.include_router(web.router, prefix="/web", tags=["web"])
app.include_router(connectors.router, prefix="/connectors", tags=["connectors"])
app.include_router(skills.router, prefix="/skills", tags=["skills"])
app.include_router(dictation.router, prefix="/dictation", tags=["dictation"])
app.include_router(capabilities.router, prefix="/capabilities", tags=["capabilities"])
app.include_router(spotify.router, prefix="/spotify", tags=["spotify"])
app.include_router(atoll.router, prefix="/atoll", tags=["atoll"])
