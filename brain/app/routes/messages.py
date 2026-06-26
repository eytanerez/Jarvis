from __future__ import annotations

from fastapi import APIRouter, Depends

from .deps import require_auth

# Scaffolding for an upcoming messages connector. No endpoints yet: this
# optimization pass deliberately does not add new features. Wire this router
# into main.py when messages support lands.
router = APIRouter(dependencies=[Depends(require_auth)])
