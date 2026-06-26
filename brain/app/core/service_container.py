from __future__ import annotations

import threading
from typing import TYPE_CHECKING, Optional

from .performance import PerformanceSettings

if TYPE_CHECKING:  # avoid importing heavy modules at type-check time only
    from ..chat_service import ChatService
    from ..file_index import FileIndexService
    from ..memory_service import MemoryService
    from ..provider_manager import ProviderManager
    from ..runtime_secrets import RuntimeSecrets
    from .modes import ModeRegistry
    from .prompts import PromptService
    from .scheduled_agents import ScheduledAgentService
    from .skills import SkillManager
    from .capabilities import CapabilityRegistry
    from ..dictation import DictationService
    from ..tts_service import TTSService
    from ..web_search import WebSearch
    from ..atoll_bridge import AtollBridge
    from ..spotify_service import SpotifyService


class ServiceContainer:
    """Owns one instance of every brain service and builds them lazily.

    Creating the container is cheap: nothing heavy (TTS models, F5-TTS
    subprocess, file scans, memory embeddings) runs until the matching service
    is first requested. ``main.py`` and every route share a single container, so
    ``/files/*`` and chat file logic use the same ``FileIndexService``,
    ``/providers/*`` and chat share one ``ProviderManager``, and ``/memory/*``
    and chat share one ``MemoryService``.
    """

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._performance: Optional[PerformanceSettings] = None
        self._runtime_secrets: Optional["RuntimeSecrets"] = None
        self._memory_service: Optional["MemoryService"] = None
        self._provider_manager: Optional["ProviderManager"] = None
        self._tts_service: Optional["TTSService"] = None
        self._web_search: Optional["WebSearch"] = None
        self._file_index_service: Optional["FileIndexService"] = None
        self._mode_registry: Optional["ModeRegistry"] = None
        self._prompt_service: Optional["PromptService"] = None
        self._scheduled_agent_service: Optional["ScheduledAgentService"] = None
        self._skill_manager: Optional["SkillManager"] = None
        self._capability_registry: Optional["CapabilityRegistry"] = None
        self._dictation_service: Optional["DictationService"] = None
        self._chat_service: Optional["ChatService"] = None
        self._atoll_bridge: Optional["AtollBridge"] = None
        self._spotify_service: Optional["SpotifyService"] = None

    @property
    def performance(self) -> PerformanceSettings:
        with self._lock:
            if self._performance is None:
                self._performance = PerformanceSettings()
            return self._performance

    @property
    def runtime_secrets(self) -> "RuntimeSecrets":
        with self._lock:
            if self._runtime_secrets is None:
                from ..runtime_secrets import RuntimeSecrets

                self._runtime_secrets = RuntimeSecrets.from_environment()
            return self._runtime_secrets

    @property
    def memory_service(self) -> "MemoryService":
        with self._lock:
            if self._memory_service is None:
                from ..memory_service import MemoryService

                self._memory_service = MemoryService(secrets=self.runtime_secrets)
            return self._memory_service

    @property
    def provider_manager(self) -> "ProviderManager":
        with self._lock:
            if self._provider_manager is None:
                from ..provider_manager import ProviderManager

                self._provider_manager = ProviderManager(secrets=self.runtime_secrets)
            return self._provider_manager

    @property
    def tts_service(self) -> "TTSService":
        with self._lock:
            if self._tts_service is None:
                from ..tts_service import TTSService

                self._tts_service = TTSService()
            return self._tts_service

    @property
    def web_search(self) -> "WebSearch":
        with self._lock:
            if self._web_search is None:
                from ..web_search import WebSearch

                self._web_search = WebSearch()
            return self._web_search

    @property
    def file_index_service(self) -> "FileIndexService":
        with self._lock:
            if self._file_index_service is None:
                from ..file_index import FileIndexService

                self._file_index_service = FileIndexService(
                    default_mode=self.performance.file_index_default_mode
                )
            return self._file_index_service

    @property
    def mode_registry(self) -> "ModeRegistry":
        with self._lock:
            if self._mode_registry is None:
                from .modes import ModeRegistry

                self._mode_registry = ModeRegistry()
            return self._mode_registry

    @property
    def prompt_service(self) -> "PromptService":
        with self._lock:
            if self._prompt_service is None:
                from .prompts import PromptService

                self._prompt_service = PromptService()
            return self._prompt_service

    @property
    def scheduled_agent_service(self) -> "ScheduledAgentService":
        with self._lock:
            if self._scheduled_agent_service is None:
                from .scheduled_agents import ScheduledAgentService

                self._scheduled_agent_service = ScheduledAgentService()
            return self._scheduled_agent_service

    @property
    def skill_manager(self) -> "SkillManager":
        with self._lock:
            if self._skill_manager is None:
                from .skills import SkillManager

                self._skill_manager = SkillManager()
            return self._skill_manager

    @property
    def atoll_bridge(self) -> "AtollBridge":
        with self._lock:
            if self._atoll_bridge is None:
                from ..atoll_bridge import AtollBridge

                self._atoll_bridge = AtollBridge()
            return self._atoll_bridge

    @property
    def spotify_service(self) -> "SpotifyService":
        with self._lock:
            if self._spotify_service is None:
                from ..spotify_service import SpotifyService

                self._spotify_service = SpotifyService(secrets=self.runtime_secrets)
            return self._spotify_service

    @property
    def capability_registry(self) -> "CapabilityRegistry":
        with self._lock:
            if self._capability_registry is None:
                from .capabilities import CapabilityRegistry

                self._capability_registry = CapabilityRegistry(
                    providers=self.provider_manager,
                    memory=self.memory_service,
                    file_index=self.file_index_service,
                    web=self.web_search,
                    skill_manager=self.skill_manager,
                    dictation=self.dictation_service,
                    tts=self.tts_service,
                    atoll=self.atoll_bridge,
                    spotify=self.spotify_service,
                )
            return self._capability_registry

    @property
    def dictation_service(self) -> "DictationService":
        with self._lock:
            if self._dictation_service is None:
                from ..dictation import DictationService

                self._dictation_service = DictationService(prompts=self.prompt_service)
            return self._dictation_service

    @property
    def chat_service(self) -> "ChatService":
        with self._lock:
            if self._chat_service is None:
                from ..chat_service import ChatService

                self._chat_service = ChatService(
                    secrets=self.runtime_secrets,
                    memory=self.memory_service,
                    providers=self.provider_manager,
                    web=self.web_search,
                    file_index=self.file_index_service,
                    performance=self.performance,
                    mode_registry=self.mode_registry,
                    prompts=self.prompt_service,
                    skill_manager=self.skill_manager,
                    capability_registry=self.capability_registry,
                )
            return self._chat_service
