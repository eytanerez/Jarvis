from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Mapping, Optional, Tuple


PROVIDERS: Tuple[str, ...] = ("openai", "anthropic", "gemini")


@dataclass(frozen=True)
class RuntimeSecrets:
    geminiApiKey: Optional[str] = None
    openaiApiKey: Optional[str] = None
    anthropicApiKey: Optional[str] = None
    providerOrder: Tuple[str, ...] = PROVIDERS

    @classmethod
    def from_environment(cls, environ: Optional[Mapping[str, str]] = None) -> "RuntimeSecrets":
        env = os.environ if environ is None else environ
        configured_order = tuple(
            provider
            for provider in (
                cls._normalize_provider(part)
                for part in env.get("JARVIS_PROVIDER_ORDER", "openai,anthropic,gemini").split(",")
            )
            if provider
        )
        provider_order = configured_order + tuple(provider for provider in PROVIDERS if provider not in configured_order)
        return cls(
            geminiApiKey=cls._first_value(env, "JARVIS_GEMINI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"),
            openaiApiKey=cls._first_value(env, "JARVIS_OPENAI_API_KEY", "OPENAI_API_KEY"),
            anthropicApiKey=cls._first_value(env, "JARVIS_ANTHROPIC_API_KEY", "ANTHROPIC_API_KEY"),
            providerOrder=provider_order,
        )

    def key_for(self, provider: str) -> Optional[str]:
        if provider == "gemini":
            return self.geminiApiKey
        if provider == "openai":
            return self.openaiApiKey
        if provider == "anthropic":
            return self.anthropicApiKey
        return None

    def has_key(self, provider: str) -> bool:
        return bool(self.key_for(provider))

    def enabled_chain(self) -> list[str]:
        return [provider for provider in self.providerOrder if self.has_key(provider)]

    def active_provider(self) -> Optional[str]:
        chain = self.enabled_chain()
        return chain[0] if chain else None

    def key_presence(self) -> dict[str, bool]:
        return {provider: self.has_key(provider) for provider in PROVIDERS}

    @staticmethod
    def _first_value(env: Mapping[str, str], *names: str) -> Optional[str]:
        for name in names:
            value = env.get(name)
            if value and value.strip():
                return value.strip()
        return None

    @staticmethod
    def _normalize_provider(value: str) -> Optional[str]:
        normalized = value.strip().lower()
        if normalized == "openai":
            return "openai"
        if normalized in PROVIDERS:
            return normalized
        return None
