from __future__ import annotations

import re
from typing import Any, Dict, Optional

from .approval import SkillApprovalStore
from .security import SkillSecurity


class SkillLearner:
    def __init__(self, approval: SkillApprovalStore, security: Optional[SkillSecurity] = None) -> None:
        self.approval = approval
        self.security = security or SkillSecurity()

    def draft(
        self,
        source: str,
        name: Optional[str] = None,
        category: str = "personal",
        description: Optional[str] = None,
        mode: str = "quick_assistant",
    ) -> Dict[str, Any]:
        safe_source = self.security.redacted(source.strip())
        inferred_name = name or self._infer_name(safe_source)
        skill_name = self.security.sanitize_name(inferred_name)
        desc = (description or self._infer_description(safe_source, skill_name))[:60]
        content = self._skill_md(skill_name, desc, category, safe_source, mode)
        warnings = self.security.find_secret_warnings(source)
        change = self.approval.stage_skill(
            skill_name=skill_name,
            content=content,
            category=category,
            summary=f"Create learned skill `{skill_name}`.",
            warnings=warnings,
        )
        return {
            "answer": f"I drafted a skill called `{skill_name}`. Review it before I save it.",
            "speak": "I drafted it. Review before saving.",
            "skillUpdate": change.to_dict(),
            "warnings": warnings,
        }

    def _infer_name(self, source: str) -> str:
        first_line = next((line.strip() for line in source.splitlines() if line.strip()), "learned workflow")
        first_line = re.sub(r"^(learn|remember|make|create)\s+", "", first_line, flags=re.IGNORECASE)
        return first_line[:50] or "learned workflow"

    def _infer_description(self, source: str, name: str) -> str:
        verbs = " ".join(source.split())[:90]
        if verbs:
            return verbs[:60]
        return name.replace("-", " ").title()

    def _skill_md(self, name: str, description: str, category: str, source: str, mode: str) -> str:
        procedure = self._procedure_from_source(source)
        return f"""---
name: {name}
description: {description}
version: 1.0.0
platforms: [macos]
category: {category}
risk_level: green
requires_confirmation: false
allowed_modes: [{mode}]
required_connectors: []
required_permissions: []
required_secrets: []
config: []
---

# {name.replace('-', ' ').title()}

## When to Use
Use this when the user asks Jarvis to repeat this workflow or refers to `{name}`.

## Inputs Needed
- The user's current goal.
- Any current Mac context the workflow depends on.

## Procedure
{procedure}

## Safety and Confirmation
Do not send messages, delete files, run shell commands, or change external systems without explicit confirmation.

## Pitfalls
- Do not store or reveal secrets.
- If source details are missing, ask one specific clarification.
- Do not claim an action happened until the app reports the result.

## Verification
Confirm the output matches the requested workflow and list any assumptions.

## Response Style
Be direct, natural, and concise. For drafts, tell the user to review before sending.
"""

    def _procedure_from_source(self, source: str) -> str:
        lines = [line.strip("-* 1234567890.").strip() for line in source.splitlines() if line.strip()]
        if not lines:
            return "1. Ask what workflow the user wants to run.\n2. Follow the user's described procedure.\n3. Verify the result."
        return "\n".join(f"{index}. {line}" for index, line in enumerate(lines[:12], start=1))
