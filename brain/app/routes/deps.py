from __future__ import annotations

from typing import Optional

from fastapi import Header, HTTPException, Request

from ..core.service_container import ServiceContainer
from ..security import token_is_valid


def get_container(request: Request) -> ServiceContainer:
    """Return the single shared ServiceContainer created in ``main.py``."""
    return request.app.state.container


def require_auth(x_jarvis_token: Optional[str] = Header(default=None)) -> None:
    if not token_is_valid(x_jarvis_token):
        raise HTTPException(status_code=401, detail="Invalid Jarvis token")
