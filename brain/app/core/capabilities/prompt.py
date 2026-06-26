from __future__ import annotations

from typing import Any, Iterable, Optional

from ..self_model.capability_manifest import CapabilityManifest
from ..self_model.identity import JarvisIdentity
from .loader import CapabilityLoader


class CapabilityPromptBuilder:
    def __init__(self, registry: Optional[Any] = None, loader: Optional[CapabilityLoader] = None) -> None:
        self.registry = registry
        self.loader = loader or CapabilityLoader()

    def build_for_turn(
        self,
        mode: str,
        situation: Optional[Any] = None,
        enabled_connectors: Optional[Iterable[str]] = None,
        available_permissions: Optional[Iterable[str]] = None,
        installed_skills: Optional[list[dict]] = None,
        active_context: Optional[dict] = None,
    ) -> str:
        if self.registry is not None:
            manifest = self.registry.manifest(
                mode=mode,
                situation=situation,
                enabled_connectors=enabled_connectors,
                available_permissions=available_permissions,
                installed_skills=installed_skills,
                active_context=active_context,
            )
        else:
            capabilities = self.loader.load(
                mode=mode,
                situation=situation,
                enabled_connectors=enabled_connectors,
                available_permissions=available_permissions,
                installed_skills=installed_skills,
                active_context=active_context,
            )
            manifest = CapabilityManifest.from_capabilities(
                identity=JarvisIdentity(),
                mode=mode,
                situation=situation,
                capabilities=capabilities,
                installed_skills=installed_skills or [],
            )
        return manifest.to_prompt()
