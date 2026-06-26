from __future__ import annotations

import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from .runtime_secrets import RuntimeSecrets


class ProviderManager:
    STALE_OPENAI_MODELS = {"", "gpt-5.5", "gpt-5.4-mini", "gpt-5-nano"}
    OPENAI_FALLBACK_MODELS = ["gpt-4.1-mini", "gpt-5-mini", "gpt-4o-mini"]
    GEMINI_FALLBACK_MODELS = ["gemini-3.5-flash", "gemini-3.1-flash-lite", "gemini-2.5-flash-lite", "gemini-2.5-flash"]

    def __init__(self, secrets: Optional[RuntimeSecrets] = None) -> None:
        self.secrets = secrets or RuntimeSecrets.from_environment()
        self._attempts: List[Dict[str, Any]] = []
        self._last_model_used: Optional[str] = None
        self._last_metadata: Dict[str, Any] = {}
        self._last_latency_ms: Optional[float] = None
        self._latency_by_provider: Dict[str, float] = {}

    def enabled_chain(self) -> List[str]:
        return self.secrets.enabled_chain()

    async def complete(self, messages: List[Dict[str, str]], task_type: str = "fast") -> str:
        self._last_model_used = None
        self._last_metadata = {}
        chain = self.enabled_chain()
        if not chain:
            self._last_model_used = "No provider"
            self._last_metadata = {
                "route": "missing_provider",
                "provider": None,
                "model": None,
                "warnings": ["No provider API key is configured."],
            }
            return "Add an API key in Settings before I can use the cloud model for that."

        try:
            import httpx
        except Exception as exc:
            self._last_model_used = "No provider"
            self._last_metadata = {
                "route": "provider_dependency_missing",
                "provider": None,
                "model": None,
                "warnings": [f"Python dependency missing: {self._friendly_error(exc)}"],
            }
            return "The brain provider dependency is missing, so I cannot call the cloud model yet."

        last_error: Optional[Exception] = None
        warnings: List[str] = []
        for provider in chain:
            model = self._selected_model_name(provider, task_type)
            started = time.perf_counter()
            try:
                if provider == "openai":
                    answer = await self._openai(httpx, messages, task_type)
                    used_model = self._last_model_used_name(model)
                    self._record_latency(provider, started)
                    self._record_attempt(provider, task_type, used_model, True, "Connected")
                    self._last_metadata = {
                        "route": "cloud_llm",
                        "provider": provider,
                        "model": used_model,
                        "warnings": warnings,
                    }
                    return answer
                if provider == "anthropic":
                    answer = await self._anthropic(httpx, messages, task_type)
                    self._last_model_used = f"Anthropic {model}"
                    self._record_latency(provider, started)
                    self._record_attempt(provider, task_type, model, True, "Connected")
                    self._last_metadata = {
                        "route": "cloud_llm",
                        "provider": provider,
                        "model": model,
                        "warnings": warnings,
                    }
                    return answer
                if provider == "gemini":
                    answer = await self._gemini(httpx, messages, task_type)
                    used_model = self._last_model_used_name(model)
                    self._record_latency(provider, started)
                    self._record_attempt(provider, task_type, used_model, True, "Connected")
                    self._last_metadata = {
                        "route": "cloud_llm",
                        "provider": provider,
                        "model": used_model,
                        "warnings": warnings,
                    }
                    return answer
            except Exception as exc:
                last_error = exc
                message = self._friendly_error(exc)
                warnings.append(f"{provider}: {message}")
                self._record_attempt(provider, task_type, model, False, message)
                print(f"[jarvis-brain] provider={provider} task={task_type} model={model} failed: {message}", flush=True)
                continue
        if last_error:
            self._last_model_used = "Provider failed"
            self._last_metadata = {
                "route": "provider_failed",
                "provider": None,
                "model": None,
                "warnings": warnings,
            }
            return (
                "I can see a provider key, but the model request failed. "
                "Local commands still work while I sort out the provider connection."
            )
        self._last_model_used = "No provider"
        self._last_metadata = {
            "route": "missing_provider",
            "provider": None,
            "model": None,
            "warnings": ["No enabled provider accepted the request."],
        }
        return "Add an API key in Settings before I can use the cloud model for that."

    async def test(self) -> Dict[str, Any]:
        chain = self.enabled_chain()
        results: Dict[str, Any] = {}
        try:
            import httpx
        except Exception as exc:
            return {
                "enabled": chain,
                "results": {
                    provider: {
                        "ok": False,
                        "model": None,
                        "message": f"Python dependency missing: {self._friendly_error(exc)}",
                    }
                    for provider in chain
                },
            }

        messages = [{"role": "user", "content": "Reply with exactly: ok"}]
        for provider in chain:
            model = self._selected_model_name(provider, "fast")
            try:
                if provider == "openai":
                    await self._openai(httpx, messages, "fast")
                elif provider == "anthropic":
                    await self._anthropic(httpx, messages, "fast")
                elif provider == "gemini":
                    await self._gemini(httpx, messages, "fast")
                results[provider] = {"ok": True, "model": model, "message": "Connected"}
                self._record_attempt(provider, "fast", model, True, "Provider test connected")
            except Exception as exc:
                message = self._friendly_error(exc)
                results[provider] = {
                    "ok": False,
                    "model": model,
                    "message": message,
                }
                self._record_attempt(provider, "fast", model, False, message)
        return {"enabled": chain, "results": results}

    def diagnostics(self) -> Dict[str, Any]:
        return {
            "enabled": self.enabled_chain(),
            "activeProvider": self.secrets.active_provider(),
            "keyPresence": self.secrets.key_presence(),
            "attempts": self._attempts[-25:],
        }

    def last_model_used(self) -> Optional[str]:
        return self._last_model_used

    def last_metadata(self) -> Dict[str, Any]:
        return dict(self._last_metadata)

    def last_latency_ms(self) -> Optional[float]:
        return self._last_latency_ms

    def latency_by_provider(self) -> Dict[str, float]:
        return dict(self._latency_by_provider)

    def _record_latency(self, provider: str, started: float) -> None:
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        self._last_latency_ms = elapsed_ms
        self._latency_by_provider[provider] = elapsed_ms

    async def _openai(self, httpx: Any, messages: List[Dict[str, str]], task_type: str) -> str:
        preferred = self._openai_model(self._model_for("JARVIS_OPENAI", task_type, self._openai_default(task_type)))
        last_error: Optional[Exception] = None
        for model in self._openai_model_candidates(preferred):
            try:
                answer = await self._openai_once(httpx, messages, task_type, model)
                self._last_model_used = f"OpenAI {model}"
                return answer
            except Exception as exc:
                last_error = exc
                if not self._is_model_retryable_error(exc):
                    break
        if last_error:
            raise last_error
        raise ValueError("OpenAI request failed before it was sent")

    async def _openai_once(self, httpx: Any, messages: List[Dict[str, str]], task_type: str, model: str) -> str:
        try:
            from openai import AsyncOpenAI
        except Exception:
            return await self._openai_responses_http(httpx, messages, model, task_type)

        client = AsyncOpenAI(api_key=self._required_key("openai"), timeout=25)
        instructions, input_text = self._openai_input(messages)
        kwargs = self._openai_response_kwargs(model, task_type)
        response = await client.responses.create(
            model=model,
            instructions=instructions or None,
            input=input_text,
            max_output_tokens=900,
            **kwargs,
        )
        text = getattr(response, "output_text", None)
        if text:
            return str(text)
        return self._extract_openai_text(response.model_dump())

    async def _openai_responses_http(self, httpx: Any, messages: List[Dict[str, str]], model: str, task_type: str) -> str:
        instructions, input_text = self._openai_input(messages)
        body: Dict[str, Any] = {
            "model": model,
            "input": input_text,
            "max_output_tokens": 900,
        }
        body.update(self._openai_response_kwargs(model, task_type))
        if instructions:
            body["instructions"] = instructions
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.post(
                "https://api.openai.com/v1/responses",
                headers={"Authorization": f"Bearer {self._required_key('openai')}"},
                json=body,
            )
            response.raise_for_status()
            return self._extract_openai_text(response.json())

    async def _anthropic(self, httpx: Any, messages: List[Dict[str, str]], task_type: str) -> str:
        model = self._model_for("JARVIS_ANTHROPIC", task_type, "claude-sonnet-4-6")
        system = "\n".join(message["content"] for message in messages if message["role"] == "system")
        user_messages = [message for message in messages if message["role"] != "system"]
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self._required_key("anthropic"),
                    "anthropic-version": "2023-06-01",
                },
                json={"model": model, "system": system, "max_tokens": 900, "messages": user_messages},
            )
            response.raise_for_status()
            data = response.json()
            return "".join(part.get("text", "") for part in data.get("content", []))

    async def _gemini(self, httpx: Any, messages: List[Dict[str, str]], task_type: str) -> str:
        preferred = self._gemini_model(self._model_for("JARVIS_GEMINI", task_type, self._gemini_default(task_type)))
        last_error: Optional[Exception] = None
        for model in self._gemini_model_candidates(preferred):
            try:
                answer = await self._gemini_once(httpx, messages, model)
                self._last_model_used = f"Gemini {model}"
                return answer
            except Exception as exc:
                last_error = exc
                if not self._is_model_retryable_error(exc):
                    break
        if last_error:
            raise last_error
        raise ValueError("Gemini request failed before it was sent")

    async def _gemini_once(self, httpx: Any, messages: List[Dict[str, str]], model: str) -> str:
        prompt = "\n".join(f"{message['role']}: {message['content']}" for message in messages)
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.post(
                url,
                params={"key": self._required_key("gemini")},
                json={"contents": [{"parts": [{"text": prompt}]}]},
            )
            response.raise_for_status()
            data = response.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]

    def _model_for(self, prefix: str, task_type: str, default: str) -> str:
        if task_type == "fast":
            return os.environ.get(f"{prefix}_FAST_MODEL") or os.environ.get(f"{prefix}_MODEL", default)
        if task_type in {"smart", "reasoning"}:
            return (
                os.environ.get(f"{prefix}_SMART_MODEL")
                or os.environ.get(f"{prefix}_REASONING_MODEL")
                or os.environ.get(f"{prefix}_MODEL", default)
            )
        return os.environ.get(f"{prefix}_MODEL", default)

    def _selected_model_name(self, provider: str, task_type: str) -> Optional[str]:
        if provider == "openai":
            return self._openai_model(self._model_for("JARVIS_OPENAI", task_type, self._openai_default(task_type)))
        if provider == "anthropic":
            return self._model_for("JARVIS_ANTHROPIC", task_type, "claude-sonnet-4-6")
        if provider == "gemini":
            return self._gemini_model(self._model_for("JARVIS_GEMINI", task_type, self._gemini_default(task_type)))
        return None

    def _openai_input(self, messages: List[Dict[str, str]]) -> tuple[str, str]:
        instructions = "\n".join(message["content"] for message in messages if message["role"] == "system")
        input_text = "\n\n".join(
            f"{message['role']}: {message['content']}"
            for message in messages
            if message["role"] != "system"
        ).strip()
        return instructions, input_text or "user:"

    def _openai_model(self, model: str) -> str:
        normalized = model.strip()
        if normalized.lower() in self.STALE_OPENAI_MODELS:
            return "gpt-5-mini"
        return normalized

    def _openai_default(self, task_type: str) -> str:
        if task_type in {"smart", "reasoning"}:
            return "gpt-5-mini"
        return "gpt-4.1-mini"

    def _openai_model_candidates(self, preferred: str) -> List[str]:
        candidates = [preferred]
        for model in self.OPENAI_FALLBACK_MODELS:
            if model not in candidates:
                candidates.append(model)
        return candidates

    def _gemini_model(self, model: str) -> str:
        normalized = model.strip()
        replacements = {
            "gemini-3.1-flash-light": "gemini-3.1-flash-lite",
            "gemini-2.5-flash-light": "gemini-2.5-flash-lite",
            "gemini-2.0-flash-light": "gemini-2.0-flash-lite",
        }
        return replacements.get(normalized.lower(), normalized or self._gemini_default("fast"))

    def _gemini_default(self, task_type: str) -> str:
        if task_type in {"smart", "reasoning"}:
            return "gemini-3.5-flash"
        return "gemini-3.1-flash-lite"

    def _gemini_model_candidates(self, preferred: str) -> List[str]:
        candidates = [preferred]
        for model in self.GEMINI_FALLBACK_MODELS:
            if model not in candidates:
                candidates.append(model)
        return candidates

    def _openai_response_kwargs(self, model: str, task_type: str) -> Dict[str, Any]:
        if not model.startswith("gpt-5"):
            return {}
        effort = "low" if task_type == "fast" else "medium"
        return {"reasoning": {"effort": effort}, "text": {"verbosity": "low"}}

    def _is_model_retryable_error(self, exc: Exception) -> bool:
        text = self._error_text(exc).lower()
        status = getattr(exc, "status_code", None)
        response = getattr(exc, "response", None)
        if response is not None:
            status = getattr(response, "status_code", status)
        if "api key" in text or "apikey" in text or "invalid_argument" in text or "permission" in text:
            return False
        return status == 404 or "model" in text or "not found" in text or "does not exist" in text

    def _extract_openai_text(self, data: Dict[str, Any]) -> str:
        if data.get("output_text"):
            return str(data["output_text"])

        pieces: List[str] = []
        for item in data.get("output", []):
            for content in item.get("content", []):
                if isinstance(content, dict) and content.get("text"):
                    pieces.append(str(content["text"]))
        text = "".join(pieces).strip()
        if text:
            return text
        raise ValueError("OpenAI response did not include text output")

    def _friendly_error(self, exc: Exception) -> str:
        status = getattr(exc, "status_code", None)
        response = getattr(exc, "response", None)
        if response is not None:
            status = getattr(response, "status_code", status)
        text = self._error_text(exc)
        lower = text.lower()
        if status in {400, 401} and ("api key" in lower or "apikey" in lower):
            return "The API key was rejected by the provider."
        if "incorrect api key" in lower or "invalid api key" in lower or "api key not valid" in lower:
            return "The API key was rejected by the provider."
        if status == 403 or "permission" in lower:
            return "The key does not have access to that model or project."
        if status == 404 or "model" in lower:
            return "The configured model is not available to this key."
        if "insufficient_quota" in lower or "quota" in lower or "billing" in lower:
            return "The OpenAI project has no available quota or billing is not enabled."
        if status == 429 or "rate limit" in lower:
            return "The provider rate limit was reached."
        if len(text) > 220:
            return text[:217] + "..."
        return text or exc.__class__.__name__

    def _error_text(self, exc: Exception) -> str:
        response = getattr(exc, "response", None)
        if response is not None:
            try:
                body = response.text
                if body:
                    return body
            except Exception:
                pass
        return str(exc)

    def _record_attempt(self, provider: str, task_type: str, model: Optional[str], ok: bool, message: str) -> None:
        self._attempts.append(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "provider": provider,
                "taskType": task_type,
                "model": model,
                "ok": ok,
                "message": message,
            }
        )
        if len(self._attempts) > 50:
            self._attempts = self._attempts[-50:]

    def _last_model_used_name(self, fallback: Optional[str]) -> Optional[str]:
        if self._last_model_used and " " in self._last_model_used:
            return self._last_model_used.split(" ", 1)[1]
        return fallback

    def _required_key(self, provider: str) -> str:
        key = self.secrets.key_for(provider)
        if not key:
            raise ValueError(f"{provider} API key is not configured")
        return key
