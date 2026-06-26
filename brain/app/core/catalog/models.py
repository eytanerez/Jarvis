from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Tuple

# Canonical catalog version. Bump when the catalog content changes so the
# generator rewrites managed SKILL.md files on the next start.
CATALOG_VERSION = "1.0.0"

RISK_LEVELS: Tuple[str, ...] = ("green", "yellow", "red")

# Every value the `source:` field of a SKILL.md may take. The availability
# resolver maps each one to a live executor/connector/service check.
SOURCES: Tuple[str, ...] = (
    "brain_service",
    "local_skill",
    "swift_action",
    "connector",
    "atoll_apple_bridge",
    "spotify_api",
    "file_index",
    "memory",
    "web",
    "provider",
    "tts",
    "scheduler",
)

# Folder category -> capability category. Folders that don't appear here use
# their own name as the capability category.
CATEGORY_TO_CAPABILITY_CATEGORY = {
    "assistant": "assistant_core",
    "macos": "mac_actions",
    "writing": "documents",
    "dev": "developer",
}

# Default allowed modes per folder category. Everything stays matchable in
# quick_assistant so normal chat can select installed skills.
_MODE_BY_CATEGORY = {
    "dictation": ["dictation", "quick_assistant"],
    "email": ["email_writer", "quick_assistant"],
    "writing": ["document_editor", "quick_assistant"],
    "research": ["deep_research", "quick_assistant"],
    "dev": ["code_helper", "quick_assistant"],
    "automation": ["daily_brief", "quick_assistant"],
}

# Default macOS permission hints per folder category. The Swift side is the
# real permission gate; these document what the skill needs.
_PERMISSIONS_BY_CATEGORY = {
    "calendar": ["calendar"],
    "reminders": ["reminders"],
    "contacts": ["contacts"],
    "phone": ["contacts"],
    "messages": ["accessibility"],
    "notes": ["notes"],
    "dictation": ["microphone", "accessibility"],
    "writing": ["accessibility"],
    "browser": ["automation", "accessibility"],
    "macos": ["automation"],
    "system": ["automation"],
    "windows": ["automation"],
    "focus": ["automation"],
    "clipboard": ["accessibility"],
    "screen": ["screen_recording", "accessibility"],
    "apps": ["accessibility", "automation"],
    "meetings": ["automation"],
    "photos": ["photos"],
    "files": ["file_index"],
    "pdf": ["file_index"],
}


def capability_category(category: str) -> str:
    return CATEGORY_TO_CAPABILITY_CATEGORY.get(category, category)


@dataclass(frozen=True)
class SkillDef:
    """One canonical skill. Drives a SKILL.md file *and* a capability record."""

    category: str
    name: str
    description: str
    risk_level: str = "green"
    source: str = "brain_service"
    version: str = "1.0.0"
    platforms: List[str] = field(default_factory=lambda: ["macos"])
    allowed_modes: List[str] = field(default_factory=list)
    required_connectors: List[str] = field(default_factory=list)
    required_permissions: List[str] = field(default_factory=list)
    required_secrets: List[str] = field(default_factory=list)
    executor: str = ""
    data_access: str = "local_only"
    aliases: List[str] = field(default_factory=list)
    examples: List[str] = field(default_factory=list)
    how_to_use: str = ""

    @property
    def path(self) -> str:
        return f"{self.category}/{self.name}"

    @property
    def capability_id(self) -> str:
        return f"{self.category}.{self.name}"

    @property
    def capability_category(self) -> str:
        return capability_category(self.category)

    @property
    def requires_confirmation(self) -> bool:
        return self.risk_level in {"yellow", "red"}

    @property
    def requires_typed_confirmation(self) -> bool:
        # The most destructive/irreversible red actions warrant typed confirm.
        if self.risk_level != "red":
            return False
        return any(token in self.name for token in ("delete", "shutdown", "restart", "shut-down"))

    def modes(self) -> List[str]:
        if self.allowed_modes:
            return list(self.allowed_modes)
        if self.category == "skills" and any(token in self.name for token in ("learn", "approve", "reject", "diff", "delete", "create-bundle")):
            return ["skill_learning", "quick_assistant"]
        return list(_MODE_BY_CATEGORY.get(self.category, ["quick_assistant"]))

    def permissions(self) -> List[str]:
        if self.required_permissions:
            return list(self.required_permissions)
        return list(_PERMISSIONS_BY_CATEGORY.get(self.category, []))

    def title(self) -> str:
        return self.name.replace("-", " ").title()
