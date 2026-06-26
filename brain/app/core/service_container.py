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
    from ..tts_service import TTSService
    from ..web_search import WebSearch


class ServiceContainer:
    """Owns one instance of every brain service and builds them lazily.

    Creating the container is cheap: nothing heavy (TTS models, Chatterbox
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
        self._chat_service: Optional["ChatService"] = None

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
                )
            return self._chat_service
