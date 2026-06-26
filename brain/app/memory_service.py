from __future__ import annotations

import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from .runtime_secrets import RuntimeSecrets


class MemoryService:
    def __init__(self, secrets: Optional[RuntimeSecrets] = None) -> None:
        self.secrets = secrets or RuntimeSecrets.from_environment()
        self.home = Path(os.environ.get("JARVIS_BRAIN_HOME", Path.home() / "Library/Application Support/JarvisNotch"))
        self.home.mkdir(parents=True, exist_ok=True)
        self.fallback_path = self.home / "memories.json"
        self.profile_path = Path(
            os.environ.get("JARVIS_USER_PROFILE_MEMORY_PATH", self.home / "user_profile_memory.md")
        )
        self._mem0: Any = None
        self._mem0_checked = False
        self._mem0_provider: Optional[str] = None
        self._mem0_embedder_provider: Optional[str] = None
        self.last_error: Optional[str] = None

    def add(self, text: str, metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        metadata = metadata or {}
        metadata.setdefault("category", self._category_for(text, metadata))
        metadata.setdefault("source", metadata.get("source") or "explicit_user_request")
        metadata.setdefault("confidence", metadata.get("confidence", 1.0))
        mem0 = self._mem0_client()
        if mem0 is not None:
            try:
                result = mem0.add(text, user_id="eytan", metadata=metadata)
                self.last_error = None
                return {
                    "id": str(uuid.uuid4()),
                    "text": text,
                    "category": metadata.get("category"),
                    "confidence": metadata.get("confidence"),
                    "source": metadata.get("source"),
                    "provider": "mem0",
                    "createdAt": self._now(),
                    "lastUsedAt": None,
                    "raw": result,
                }
            except Exception as exc:
                self.last_error = self._friendly_mem0_error(exc)

        memories = self._load_fallback()
        item = {
            "id": str(uuid.uuid4()),
            "text": text,
            "category": metadata.get("category"),
            "confidence": metadata.get("confidence"),
            "source": metadata.get("source"),
            "createdAt": self._now(),
            "lastUsedAt": None,
            "metadata": metadata,
            "provider": "json",
        }
        memories.append(item)
        self._save_fallback(memories)
        return item

    def search(self, query: str, limit: int = 8) -> List[Dict[str, Any]]:
        mem0 = self._mem0_client()
        if mem0 is not None:
            try:
                result = mem0.search(query, user_id="eytan", limit=limit)
                self.last_error = None
                if isinstance(result, list):
                    return self._with_profile_results(query, result, limit)
                if isinstance(result, dict):
                    return self._with_profile_results(query, result.get("results", []), limit)
            except Exception as exc:
                self.last_error = self._friendly_mem0_error(exc)

        terms = {part.lower() for part in query.split() if len(part) > 2}
        scored = []
        memories = self._load_fallback()
        for item in memories:
            text = item.get("text", "")
            score = sum(1 for term in terms if term in text.lower())
            if score > 0 or not terms:
                scored.append((score, item))
        scored.sort(key=lambda pair: pair[0], reverse=True)
        results = [item for _, item in scored[:limit]]
        if results:
            used_at = self._now()
            ids = {item.get("id") for item in results}
            for item in memories:
                if item.get("id") in ids:
                    item["lastUsedAt"] = used_at
            self._save_fallback(memories)
        return self._with_profile_results(query, results, limit)

    def list(self) -> List[Dict[str, Any]]:
        memories = self._load_fallback()
        profile = self.profile_memory()
        return ([profile] if profile else []) + memories

    def profile_memory(self) -> Optional[Dict[str, Any]]:
        text = self._load_profile_text()
        if not text:
            return None
        return {
            "id": "user_profile_memory",
            "text": text,
            "category": "profile",
            "confidence": 1.0,
            "source": "user_profile_memory_file",
            "createdAt": self._profile_timestamp(),
            "lastUsedAt": None,
            "metadata": {
                "category": "profile",
                "source": "user_profile_memory_file",
                "path": str(self.profile_path),
            },
            "provider": "profile_file",
        }

    def status(self) -> Dict[str, Any]:
        mem0 = self._mem0_client()
        mem0_active = mem0 is not None and self.last_error is None
        active_model_provider = self.secrets.active_provider()
        fallback_reason = None if mem0_active else self.last_error or "mem0 is not initialized; using JSON fallback."
        return {
            "activeProvider": "mem0" if mem0_active else "json",
            "activeModelProvider": active_model_provider,
            "activeModelProviderDisplayName": self._provider_display_name(active_model_provider),
            "geminiKeyConfigured": self.secrets.has_key("gemini"),
            "brainReceivedGeminiKey": bool(self.secrets.geminiApiKey),
            "memoryBackend": "mem0 active" if mem0_active else "JSON fallback",
            "fallbackReason": fallback_reason,
            "mem0Available": mem0 is not None,
            "mem0Provider": self._mem0_provider,
            "mem0EmbedderProvider": self._mem0_embedder_provider,
            "fallbackPath": str(self.fallback_path),
            "fallbackCount": len(self._load_fallback()),
            "profilePath": str(self.profile_path),
            "profileMemoryPresent": self.profile_memory() is not None,
            "lastError": self.last_error,
        }

    def delete(self, memory_id: str) -> bool:
        memories = self._load_fallback()
        kept = [item for item in memories if item.get("id") != memory_id]
        self._save_fallback(kept)
        return len(kept) != len(memories)

    def edit(self, memory_id: str, text: Optional[str] = None, metadata: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        memories = self._load_fallback()
        for item in memories:
            if item.get("id") != memory_id:
                continue
            if text is not None:
                item["text"] = text
            if metadata is not None:
                merged = dict(item.get("metadata") or {})
                merged.update(metadata)
                item["metadata"] = merged
                if "category" in metadata:
                    item["category"] = metadata["category"]
                if "confidence" in metadata:
                    item["confidence"] = metadata["confidence"]
                if "source" in metadata:
                    item["source"] = metadata["source"]
            self._save_fallback(memories)
            return item
        return None

    def _mem0_client(self) -> Any:
        if not self._mem0_checked:
            self._mem0_checked = True
            self._mem0 = self._build_mem0()
        return self._mem0

    def _build_mem0(self) -> Any:
        try:
            config = self._mem0_config()
            from mem0 import Memory

            client = Memory.from_config(config)
            self.last_error = None
            return client
        except Exception as exc:
            self.last_error = self._friendly_mem0_error(exc)
            return None

    def _mem0_config(self) -> Dict[str, Any]:
        active_provider = self.secrets.active_provider()
        if active_provider is None:
            raise ValueError("No provider API key is configured for memory.")

        llm = self._llm_config(active_provider)
        embedder = self._embedder_config(active_provider)
        self._mem0_provider = llm["provider"]
        self._mem0_embedder_provider = embedder["provider"]
        collection_name = f"jarvis_memories_{llm['provider']}_{embedder['provider']}"
        return {
            "llm": llm,
            "embedder": embedder,
            "vector_store": {
                "provider": "chroma",
                "config": {
                    "collection_name": collection_name,
                    "path": str(self.home / "chroma"),
                },
            },
            "history_db_path": str(self.home / "mem0_history.db"),
        }

    def _llm_config(self, provider: str) -> Dict[str, Any]:
        if provider == "gemini":
            return {
                "provider": "gemini",
                "config": {
                    "model": self._gemini_model(
                        os.environ.get("JARVIS_MEM0_GEMINI_LLM_MODEL")
                        or os.environ.get("JARVIS_MEM0_LLM_MODEL")
                        or os.environ.get("JARVIS_GEMINI_FAST_MODEL", "gemini-2.0-flash")
                    ),
                    "api_key": self._required_key("gemini"),
                    "temperature": 0.1,
                },
            }
        if provider == "openai":
            return {
                "provider": "openai",
                "config": {
                    "model": self._openai_model(
                        os.environ.get("JARVIS_MEM0_OPENAI_LLM_MODEL")
                        or os.environ.get("JARVIS_MEM0_LLM_MODEL")
                        or os.environ.get("JARVIS_OPENAI_FAST_MODEL", "gpt-4.1-mini")
                    ),
                    "api_key": self._required_key("openai"),
                    "temperature": 0.1,
                },
            }
        if provider == "anthropic":
            return {
                "provider": "anthropic",
                "config": {
                    "model": (
                        os.environ.get("JARVIS_MEM0_ANTHROPIC_LLM_MODEL")
                        or os.environ.get("JARVIS_MEM0_LLM_MODEL")
                        or os.environ.get("JARVIS_ANTHROPIC_FAST_MODEL", "claude-sonnet-4-6")
                    ),
                    "api_key": self._required_key("anthropic"),
                    "temperature": 0.1,
                },
            }
        raise ValueError(f"Memory provider is not supported: {provider}")

    def _embedder_config(self, provider: str) -> Dict[str, Any]:
        if provider == "gemini":
            return self._gemini_embedder_config()
        if provider == "openai":
            return self._openai_embedder_config()
        if provider == "anthropic":
            if self.secrets.geminiApiKey:
                return self._gemini_embedder_config()
            if self.secrets.openaiApiKey:
                return self._openai_embedder_config()
            raise ValueError("mem0 needs Gemini or OpenAI embeddings when Anthropic is the active provider.")
        raise ValueError(f"Memory embedder provider is not supported: {provider}")

    def _gemini_embedder_config(self) -> Dict[str, Any]:
        return {
            "provider": "gemini",
            "config": {
                "model": os.environ.get("JARVIS_MEM0_GEMINI_EMBEDDING_MODEL", "models/gemini-embedding-001"),
                "api_key": self._required_key("gemini"),
                "embedding_dims": int(os.environ.get("JARVIS_MEM0_GEMINI_EMBEDDING_DIMS", "768")),
            },
        }

    def _openai_embedder_config(self) -> Dict[str, Any]:
        return {
            "provider": "openai",
            "config": {
                "model": os.environ.get("JARVIS_MEM0_OPENAI_EMBEDDING_MODEL", "text-embedding-3-small"),
                "api_key": self._required_key("openai"),
            },
        }

    def _openai_model(self, model: str) -> str:
        if model.strip().lower() in {"", "gpt-5.5", "gpt-5.4-mini", "gpt-5-nano"}:
            return "gpt-5-mini"
        return model

    def _gemini_model(self, model: str) -> str:
        replacements = {
            "gemini-3.1-flash-light": "gemini-3.1-flash-lite",
            "gemini-2.5-flash-light": "gemini-2.5-flash-lite",
            "gemini-2.0-flash-light": "gemini-2.0-flash-lite",
        }
        normalized = model.strip()
        return replacements.get(normalized.lower(), normalized or "gemini-2.0-flash")

    def _required_key(self, provider: str) -> str:
        key = self.secrets.key_for(provider)
        if not key:
            raise ValueError(f"{self._provider_display_name(provider)} API key is not configured for memory.")
        return key

    def _provider_display_name(self, provider: Optional[str]) -> str:
        if provider == "gemini":
            return "Gemini"
        if provider == "openai":
            return "OpenAI"
        if provider == "anthropic":
            return "Anthropic"
        return "None"

    def _friendly_mem0_error(self, exc: Exception) -> str:
        text = str(exc)
        if self.secrets.active_provider() == "gemini" and (
            "OPENAI_API_KEY" in text or "openai" in text.lower()
        ):
            return "mem0 could not initialize with Gemini settings; using JSON fallback."
        return text

    def _load_fallback(self) -> List[Dict[str, Any]]:
        if not self.fallback_path.exists():
            return []
        try:
            data = json.loads(self.fallback_path.read_text(encoding="utf-8"))
            return data if isinstance(data, list) else []
        except Exception:
            return []

    def _save_fallback(self, memories: List[Dict[str, Any]]) -> None:
        self.fallback_path.write_text(json.dumps(memories, indent=2), encoding="utf-8")

    def _load_profile_text(self) -> Optional[str]:
        try:
            text = self.profile_path.read_text(encoding="utf-8").strip()
        except Exception:
            return None
        return text or None

    def _profile_timestamp(self) -> Optional[str]:
        try:
            return (
                datetime.fromtimestamp(self.profile_path.stat().st_mtime, timezone.utc)
                .isoformat()
                .replace("+00:00", "Z")
            )
        except Exception:
            return None

    def _with_profile_results(self, query: str, results: List[Dict[str, Any]], limit: int) -> List[Dict[str, Any]]:
        if limit <= 0:
            return []
        profile = self.profile_memory()
        if not profile or not self._profile_matches(query, profile["text"]):
            return results[:limit]
        without_profile = [
            item
            for item in results
            if item.get("id") != profile["id"] and item.get("provider") != "profile_file"
        ]
        return [profile] + without_profile[: max(0, limit - 1)]

    def _profile_matches(self, query: str, text: str) -> bool:
        lower_query = query.lower()
        if any(phrase in lower_query for phrase in ["about me", "know about me", "who am i", "my profile"]):
            return True
        ignored = {
            "about",
            "are",
            "for",
            "from",
            "know",
            "memory",
            "remember",
            "system",
            "tell",
            "that",
            "the",
            "this",
            "user",
            "what",
            "who",
            "with",
            "you",
            "your",
        }
        parts = [part for part in re.findall(r"[a-z0-9#]+", lower_query) if len(part) > 2]
        if not parts:
            return True
        terms = {part for part in parts if part not in ignored}
        if not terms:
            return False
        lower_text = text.lower()
        return any(term in lower_text for term in terms)

    def _category_for(self, text: str, metadata: Dict[str, Any]) -> str:
        if metadata.get("category"):
            return str(metadata["category"])
        if metadata.get("kind"):
            return str(metadata["kind"])
        lower = text.lower()
        if "style" in lower or "write" in lower or "writing" in lower:
            return "writing_style"
        if "project" in lower or "building" in lower or "working on" in lower:
            return "projects"
        if "prefer" in lower or "like" in lower:
            return "preferences"
        if "decided" in lower or "decision" in lower:
            return "decisions"
        if "every day" in lower or "usually" in lower or "routine" in lower:
            return "routines"
        return "facts"

    def _now(self) -> str:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
