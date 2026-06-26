from __future__ import annotations

from typing import Any, Iterable, Optional

from ..self_model.capability_manifest import CapabilityManifest
from ..self_model.feature_manual import FeatureManual
from ..self_model.identity import JarvisIdentity
from .capability import Capability
from .loader import CapabilityLoader


class CapabilityRegistry:
    def __init__(
        self,
        loader: Optional[CapabilityLoader] = None,
        identity: Optional[JarvisIdentity] = None,
        **services: Any,
    ) -> None:
        self.identity = identity or JarvisIdentity()
        self.loader = loader or CapabilityLoader(**services)
        self.manual = FeatureManual()

    def capabilities(
        self,
        mode: str = "quick_assistant",
        situation: Optional[Any] = None,
        enabled_connectors: Optional[Iterable[str]] = None,
        available_permissions: Optional[Iterable[str]] = None,
        installed_skills: Optional[list[dict]] = None,
        active_context: Optional[dict] = None,
    ) -> list[Capability]:
        return self.loader.load(
            mode=mode,
            situation=situation,
            enabled_connectors=enabled_connectors,
            available_permissions=available_permissions,
            installed_skills=installed_skills,
            active_context=active_context,
        )

    def manifest(
        self,
        mode: str = "quick_assistant",
        situation: Optional[Any] = None,
        enabled_connectors: Optional[Iterable[str]] = None,
        available_permissions: Optional[Iterable[str]] = None,
        installed_skills: Optional[list[dict]] = None,
        active_context: Optional[dict] = None,
    ) -> CapabilityManifest:
        capabilities = self.capabilities(
            mode=mode,
            situation=situation,
            enabled_connectors=enabled_connectors,
            available_permissions=available_permissions,
            installed_skills=installed_skills,
            active_context=active_context,
        )
        return CapabilityManifest.from_capabilities(
            identity=self.identity,
            mode=mode,
            situation=situation,
            capabilities=capabilities,
            installed_skills=installed_skills or self.loader._safe_installed_skills(),
        )

    def status(
        self,
        mode: str = "quick_assistant",
        situation: Optional[Any] = None,
        active_context: Optional[dict] = None,
    ) -> dict:
        manifest = self.manifest(mode=mode, situation=situation, active_context=active_context)
        return manifest.to_dict()

    def explain(
        self,
        query: str = "What can you do?",
        mode: str = "quick_assistant",
        situation: Optional[Any] = None,
        active_context: Optional[dict] = None,
    ) -> str:
        manifest = self.manifest(mode=mode, situation=situation, active_context=active_context)
        return self.manual.explain(query=query, manifest=manifest)
