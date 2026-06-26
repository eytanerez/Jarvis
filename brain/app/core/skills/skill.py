from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class SkillMetadata:
    name: str
    description: str
    version: str = "1.0.0"
    platforms: List[str] = field(default_factory=lambda: ["macos"])
    category: str = "personal"
    risk_level: str = "green"
    requires_confirmation: bool = False
    allowed_modes: List[str] = field(default_factory=lambda: ["quick_assistant"])
    required_connectors: List[str] = field(default_factory=list)
    required_permissions: List[str] = field(default_factory=list)
    required_secrets: List[str] = field(default_factory=list)
    config: List[Dict[str, Any]] = field(default_factory=list)
    source: str = "brain_service"
    executor: str = ""
    data_access: str = "local_only"
    aliases: List[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SkillMetadata":
        return cls(
            name=str(data.get("name") or "untitled-skill"),
            description=str(data.get("description") or ""),
            version=str(data.get("version") or "1.0.0"),
            platforms=_as_list(data.get("platforms") or ["macos"]),
            category=str(data.get("category") or "personal"),
            risk_level=str(data.get("risk_level") or data.get("riskLevel") or "green"),
            requires_confirmation=bool(data.get("requires_confirmation") or data.get("requiresConfirmation") or False),
            allowed_modes=_as_list(data.get("allowed_modes") or data.get("allowedModes") or ["quick_assistant"]),
            required_connectors=_as_list(data.get("required_connectors") or data.get("requiredConnectors") or []),
            required_permissions=_as_list(data.get("required_permissions") or data.get("requiredPermissions") or []),
            required_secrets=_as_list(data.get("required_secrets") or data.get("requiredSecrets") or []),
            config=list(data.get("config") or []),
            source=str(data.get("source") or "brain_service"),
            executor=str(data.get("executor") or ""),
            data_access=str(data.get("data_access") or data.get("dataAccess") or "local_only"),
            aliases=_as_list(data.get("aliases") or []),
        )

    def to_index(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "category": self.category,
            "riskLevel": self.risk_level,
            "allowedModes": list(self.allowed_modes),
            "requiresConfirmation": self.requires_confirmation,
            "source": self.source,
            "capabilityId": f"{self.category}.{self.name}",
        }

    def to_dict(self) -> Dict[str, Any]:
        data = self.to_index()
        data.update(
            {
                "version": self.version,
                "platforms": list(self.platforms),
                "requiredConnectors": list(self.required_connectors),
                "requiredPermissions": list(self.required_permissions),
                "requiredSecrets": list(self.required_secrets),
                "config": list(self.config),
                "executor": self.executor,
                "dataAccess": self.data_access,
                "aliases": list(self.aliases),
            }
        )
        return data


@dataclass
class Skill:
    metadata: SkillMetadata
    body: str
    path: Path
    raw: str
    warnings: List[str] = field(default_factory=list)

    @property
    def name(self) -> str:
        return self.metadata.name

    def level0(self) -> Dict[str, Any]:
        data = self.metadata.to_index()
        if self.warnings:
            data["warnings"] = list(self.warnings)
        return data

    def level1(self) -> Dict[str, Any]:
        data = self.metadata.to_dict()
        data.update(
            {
                "body": self.body,
                "raw": self.raw,
                "path": str(self.path),
                "warnings": list(self.warnings),
            }
        )
        return data


def _as_list(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, tuple):
        return [str(item) for item in value]
    return [str(value)]
