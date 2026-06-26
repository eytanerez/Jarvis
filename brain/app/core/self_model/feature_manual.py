from __future__ import annotations

from collections import defaultdict
from typing import Dict, Iterable, Optional

from .capability_manifest import CapabilityManifest


class FeatureManual:
    def explain(self, query: str, manifest: CapabilityManifest) -> str:
        lower = query.lower().strip()
        if "skill" in lower and any(phrase in lower for phrase in ["what", "list", "have", "installed"]):
            return self._skills_answer(manifest.installed_skills)
        if any(word in lower for word in ["email", "gmail", "mail"]):
            return self._category_answer("email", manifest)
        if any(word in lower for word in ["whatsapp", "message", "messages", "imessage"]):
            return self._category_answer("messages", manifest)
        if any(word in lower for word in ["document", "selected text", "edit this", "rewrite"]):
            return self._category_answer("documents", manifest)
        if any(word in lower for word in ["remember", "memory", "memories"]):
            return self._category_answer("memory", manifest)
        if any(word in lower for word in ["automate", "automation", "workflow"]):
            return self._automation_answer(manifest)
        if any(word in lower for word in ["file", "files", "folder", "download"]):
            return self._category_answer("files", manifest)
        if any(word in lower for word in ["calendar", "schedule", "free time"]):
            return self._category_answer("calendar", manifest)
        return self._general_answer(manifest)

    def _general_answer(self, manifest: CapabilityManifest) -> str:
        available = self._plain_names(manifest.available, limit=9)
        unavailable = self._notable_unavailable(manifest, limit=5)
        parts = []
        if available:
            parts.append("I can help with " + self._join(available) + ".")
        else:
            parts.append("I do not have any live capabilities advertised for this turn yet.")
        if unavailable:
            parts.append("Unavailable right now: " + "; ".join(unavailable) + ".")
        parts.append("Drafting is allowed, but sending, deleting, shell commands, and other risky actions require confirmation.")
        return " ".join(parts)

    def _category_answer(self, category: str, manifest: CapabilityManifest) -> str:
        capabilities = [item for item in manifest.available + manifest.unavailable if item.get("category") == category]
        if not capabilities:
            return f"I do not have any registered {category} capabilities right now."
        available = [self._capability_sentence(item) for item in capabilities if item.get("available")]
        unavailable = [self._capability_sentence(item) for item in capabilities if not item.get("available")]
        lines = []
        if available:
            lines.append("Available: " + "; ".join(available) + ".")
        if unavailable:
            lines.append("Unavailable: " + "; ".join(unavailable) + ".")
        if category in {"email", "messages"}:
            lines.append("I can draft when context is provided, but sending requires confirmation and a connected sender.")
        return " ".join(lines)

    def _automation_answer(self, manifest: CapabilityManifest) -> str:
        automation = [
            item
            for item in manifest.available + manifest.unavailable
            if item.get("category") in {"automation", "skills", "mac_actions", "developer"}
        ]
        available = [self._capability_sentence(item) for item in automation if item.get("available")]
        unavailable = [self._capability_sentence(item) for item in automation if not item.get("available")]
        answer = []
        if available:
            answer.append("I can automate through " + "; ".join(available) + ".")
        if unavailable:
            answer.append("Limits right now: " + "; ".join(unavailable) + ".")
        answer.append("Reusable workflows can be staged as skills after you approve storing the procedure.")
        return " ".join(answer)

    def _skills_answer(self, skills: Iterable[Dict[str, object]]) -> str:
        grouped: dict[str, list[str]] = defaultdict(list)
        for skill in skills:
            category = str(skill.get("category") or "uncategorized")
            name = str(skill.get("name") or "unknown-skill")
            description = str(skill.get("description") or "").strip()
            grouped[category].append(f"{name}: {description}" if description else name)
        if not grouped:
            return "I do not see any installed skills right now."
        sections = []
        for category in sorted(grouped):
            sections.append(f"{category}: " + "; ".join(sorted(grouped[category])[:8]))
        return "Installed skills grouped by category: " + " | ".join(sections)

    def _capability_sentence(self, item: Dict[str, object]) -> str:
        name = str(item.get("name") or item.get("id"))
        reason = str(item.get("status_reason") or "").strip()
        if reason:
            return f"{name} ({reason})"
        limitations = item.get("limitations")
        if isinstance(limitations, list) and limitations:
            return f"{name} ({limitations[0]})"
        if item.get("requires_confirmation"):
            return f"{name} (requires confirmation)"
        return name

    def _notable_unavailable(self, manifest: CapabilityManifest, limit: int) -> list[str]:
        items = manifest._notable_unavailable()[:limit]
        return [self._capability_sentence(item) for item in items]

    def _plain_names(self, capabilities: list[dict], limit: int) -> list[str]:
        return [str(item.get("name") or item.get("id")) for item in capabilities[:limit]]

    def _join(self, values: list[str]) -> str:
        if len(values) <= 1:
            return values[0] if values else ""
        return ", ".join(values[:-1]) + f", and {values[-1]}"
