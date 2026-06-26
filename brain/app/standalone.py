from __future__ import annotations

import asyncio
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict

from .core.service_container import ServiceContainer
from .security import token_is_valid


def run(port: int) -> None:
    # Use the same shared container as the FastAPI app so the fallback server
    # talks to one set of services.
    container = ServiceContainer()
    service = container.chat_service

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if not self._authorized():
                self._json({"detail": "Invalid Jarvis token"}, status=401)
                return
            if self.path == "/health":
                self._json({"ok": True})
            elif self.path == "/memory/list":
                self._json({"results": service.memory.list()})
            elif self.path == "/memory/status":
                self._json(service.memory.status())
            elif self.path == "/providers/diagnostics":
                self._json(service.providers.diagnostics())
            elif self.path == "/tts/status":
                self._json({
                    "engine": "kokoro",
                    "importable": False,
                    "modelPresent": False,
                    "voicesPresent": False,
                    "chatterboxImportable": False,
                    "lastError": "FastAPI TTS endpoint is unavailable in fallback server."
                })
            elif self.path == "/settings":
                self._json({"ok": True})
            else:
                self._json({"detail": "Not found"}, status=404)

        def do_POST(self) -> None:  # noqa: N802
            if not self._authorized():
                self._json({"detail": "Invalid Jarvis token"}, status=401)
                return
            payload = self._payload()
            if self.path == "/chat":
                result = asyncio.run(
                    service.chat(
                        payload.get("message", ""),
                        payload.get("context"),
                        payload.get("session", {}),
                        payload.get("mode", "normal"),
                        intent=payload.get("intent"),
                        requires_screen_context=payload.get("requiresScreenContext"),
                    )
                )
                self._json(result)
            elif self.path == "/memory/add":
                service.memory.add(payload.get("text", ""), payload.get("metadata", {}))
                self._json(service.response("Got it.", speak="Got it."))
            elif self.path == "/memory/search":
                self._json({"results": service.memory.search(payload.get("query", ""), payload.get("limit", 8))})
            elif self.path == "/web/search":
                self._json({"results": service.web.search(payload.get("query", ""), payload.get("limit", 5))})
            elif self.path == "/providers/test":
                self._json(asyncio.run(service.providers.test()))
            elif self.path in {"/memory/delete", "/settings"}:
                self._json({"ok": True})
            else:
                self._json({"detail": "Not found"}, status=404)

        def log_message(self, format: str, *args: Any) -> None:
            return

        def _authorized(self) -> bool:
            return token_is_valid(self.headers.get("X-Jarvis-Token"))

        def _payload(self) -> Dict[str, Any]:
            length = int(self.headers.get("Content-Length", "0"))
            if length == 0:
                return {}
            return json.loads(self.rfile.read(length).decode("utf-8"))

        def _json(self, payload: Dict[str, Any], status: int = 200) -> None:
            data = json.dumps(payload, default=str).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
