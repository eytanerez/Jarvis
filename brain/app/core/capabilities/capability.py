from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Literal


RiskLevel = Literal["green", "yellow", "red"]

CAPABILITY_CATEGORIES = (
    "assistant_core",
    "skills",
    "calendar",
    "reminders",
    "clock",
    "messages",
    "email",
    "contacts",
    "phone",
    "browser",
    "mac_actions",
    "media",
    "spotify",
    "documents",
    "dictation",
    "files",
    "notes",
    "workspace",
    "memory",
    "automation",
    "research",
    "developer",
    "providers",
    "tts",
    "calibre",
    "web",
    "settings",
    # Extended capability areas.
    "notifications",
    "focus",
    "clipboard",
    "windows",
    "system",
    "screen",
    "meetings",
    "apps",
    "slack",
    "whatsapp",
    "maps",
    "weather",
    "photos",
    "pdf",
    "spreadsheets",
    "presentations",
    "security",
    "shopping",
    "finance",
    "learning",
    "travel",
    "health",
    "personal",
)


@dataclass(frozen=True)
class Capability:
    id: str
    name: str
    description: str
    category: str
    examples: list[str] = field(default_factory=list)
    enabled: bool = True
    available: bool = True
    source: str = "brain_service"
    required_permissions: list[str] = field(default_factory=list)
    required_connectors: list[str] = field(default_factory=list)
    required_secrets: list[str] = field(default_factory=list)
    allowed_modes: list[str] = field(default_factory=lambda: ["*"])
    risk_level: RiskLevel = "green"
    requires_confirmation: bool = False
    input_schema: dict[str, Any] = field(default_factory=dict)
    output_schema: dict[str, Any] = field(default_factory=dict)
    limitations: list[str] = field(default_factory=list)
    how_to_use: str = ""
    status_reason: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "category": self.category,
            "examples": list(self.examples),
            "enabled": self.enabled,
            "available": self.available,
            "source": self.source,
            "required_permissions": list(self.required_permissions),
            "required_connectors": list(self.required_connectors),
            "required_secrets": list(self.required_secrets),
            "allowed_modes": list(self.allowed_modes),
            "risk_level": self.risk_level,
            "requires_confirmation": self.requires_confirmation,
            "input_schema": dict(self.input_schema),
            "output_schema": dict(self.output_schema),
            "limitations": list(self.limitations),
            "how_to_use": self.how_to_use,
            "status_reason": self.status_reason,
        }

    def prompt_line(self) -> str:
        suffixes = []
        if self.requires_confirmation:
            suffixes.append(f"{self.risk_level} confirmation")
        if self.status_reason and not self.available:
            suffixes.append(self.status_reason)
        elif self.limitations:
            suffixes.append(self.limitations[0])
        suffix = f" ({'; '.join(suffixes)})" if suffixes else ""
        return f"{self.name} [{self.id}]{suffix}"
