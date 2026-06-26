from __future__ import annotations

import asyncio
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict
from urllib.parse import parse_qs, urlparse

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
            elif self.path == "/modes":
                self._json({"modes": container.mode_registry.list(), "defaultMode": "quick_assistant"})
            elif self.path in {"/capabilities", "/capabilities/status"}:
                self._json(container.capability_registry.status())
            elif self.path == "/tts/status":
                self._json({
                    "engine": "kokoro",
                    "importable": False,
                    "modelPresent": False,
                    "voicesPresent": False,
                    "f5TTSImportable": False,
                    "lastError": "FastAPI TTS endpoint is unavailable in fallback server."
                })
            elif self.path == "/settings":
                self._json({
                    "ok": True,
                    "performance": container.performance.to_dict(),
                    "prompts": container.prompt_service.list(editable_only=True)["prompts"],
                })
            elif self.path == "/settings/prompts":
                self._json(container.prompt_service.list(editable_only=True))
            elif self.path == "/scheduled-agents":
                self._json(container.scheduled_agent_service.list())
            elif self.path == "/skills":
                self._json({"skills": container.skill_manager.list(), "config": container.skill_manager.config()})
            elif self.path.startswith("/skills/history"):
                query = parse_qs(urlparse(self.path).query)
                limit = int((query.get("limit") or ["50"])[0])
                self._json(container.skill_manager.list_history(limit=limit))
            elif self.path == "/skills/pending":
                self._json({"changes": container.skill_manager.approval.pending()})
            elif self.path == "/skills/bundles":
                self._json({"bundles": container.skill_manager.bundles.list()})
            elif self.path == "/dictation/status":
                self._json(container.dictation_service.status())
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
            elif self.path == "/capabilities/explain":
                self._json({
                    "answer": container.capability_registry.explain(
                        query=payload.get("query") or payload.get("message") or "What can you do?",
                        mode=payload.get("mode", "quick_assistant"),
                        active_context=payload.get("context"),
                    )
                })
            elif self.path == "/skills/search":
                self._json({"skills": container.skill_manager.search(payload.get("query", ""), payload.get("mode", "quick_assistant"))})
            elif self.path == "/skills/run":
                try:
                    self._json(container.skill_manager.run(payload.get("name", ""), inputs=payload.get("inputs") or {}))
                except KeyError:
                    self._json({"detail": "Skill not found"}, status=404)
            elif self.path == "/skills/bundles/run":
                try:
                    self._json(container.skill_manager.prepare_bundle(payload.get("name", ""), query=payload.get("query", "")))
                except KeyError:
                    self._json({"detail": "Skill bundle not found"}, status=404)
            elif self.path == "/skills/learn":
                self._json(container.skill_manager.learn(payload.get("source") or payload.get("text") or "", name=payload.get("name"), category=payload.get("category", "personal")))
            elif self.path == "/skills/approve":
                try:
                    self._json(container.skill_manager.approve(payload.get("id", "")))
                except KeyError:
                    self._json({"detail": "Pending skill change not found"}, status=404)
            elif self.path == "/skills/reject":
                try:
                    self._json(container.skill_manager.reject(payload.get("id", "")))
                except KeyError:
                    self._json({"detail": "Pending skill change not found"}, status=404)
            elif self.path == "/skills/delete":
                try:
                    self._json(container.skill_manager.delete(payload.get("name", "")))
                except KeyError:
                    self._json({"detail": "Skill not found"}, status=404)
            elif self.path == "/dictation/clean":
                self._json(container.dictation_service.clean(payload.get("text", "")))
            elif self.path == "/dictation/format":
                self._json(container.dictation_service.format(payload.get("text", ""), active_app=payload.get("activeApp")))
            elif self.path == "/dictation/transcribe":
                self._json(container.dictation_service.transcribe(text=payload.get("text"), audio=payload.get("audio")))
            elif self.path == "/dictation/insert-result":
                self._json(container.dictation_service.insert_result(payload.get("text", "")))
            elif self.path in {"/memory/delete", "/settings"}:
                self._json({"ok": True})
            elif self.path == "/settings/prompts":
                try:
                    prompts = payload.get("prompts")
                    self._json(container.prompt_service.save_many(prompts if isinstance(prompts, list) else []))
                except (KeyError, PermissionError) as exc:
                    self._json({"detail": str(exc)}, status=400)
            elif self.path.startswith("/scheduled-agents/") and self.path.endswith("/preview"):
                agent_id = self.path.removeprefix("/scheduled-agents/").removesuffix("/preview").strip("/")
                try:
                    self._json(container.scheduled_agent_service.preview(agent_id, payload))
                except KeyError:
                    self._json({"detail": "Scheduled agent not found"}, status=404)
            elif self.path.startswith("/scheduled-agents/") and self.path.endswith("/record-run"):
                agent_id = self.path.removeprefix("/scheduled-agents/").removesuffix("/record-run").strip("/")
                try:
                    self._json(container.scheduled_agent_service.record_run(agent_id, payload.get("runAt")))
                except KeyError:
                    self._json({"detail": "Scheduled agent not found"}, status=404)
            elif self.path.startswith("/scheduled-agents/"):
                agent_id = self.path.removeprefix("/scheduled-agents/").strip("/")
                try:
                    self._json(container.scheduled_agent_service.update(agent_id, payload))
                except KeyError:
                    self._json({"detail": "Scheduled agent not found"}, status=404)
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
