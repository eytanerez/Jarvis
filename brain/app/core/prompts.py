from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional


@dataclass(frozen=True)
class PromptDefinition:
    id: str
    title: str
    description: str
    default_file: Optional[str]
    editable: bool = True
    default_content: str = ""


class PromptService:
    DEFINITIONS: tuple[PromptDefinition, ...] = (
        PromptDefinition(
            id="assistant",
            title="Assistant Prompt",
            description="Default assistant behavior, tone, and context rules.",
            default_file="assistant.md",
        ),
        PromptDefinition(
            id="dictation",
            title="Dictation Cleanup Prompt",
            description="How dictated speech should be cleaned before insertion.",
            default_file="dictation.md",
        ),
        PromptDefinition(
            id="email",
            title="Email Formatting Prompt",
            description="How email drafts and dictated email text should be formatted.",
            default_file="email.md",
        ),
        PromptDefinition(
            id="writing_style",
            title="Writing Style Prompt",
            description="Personal writing preferences to apply when editing or drafting.",
            default_file=None,
            default_content="",
        ),
        PromptDefinition(
            id="skill_learning",
            title="Skill Learning Prompt",
            description="How Jarvis drafts reusable SKILL.md procedures.",
            default_file="skill_learning.md",
        ),
        PromptDefinition(
            id="command_interpretation",
            title="Command Interpretation Prompt",
            description="How natural requests are mapped to modes, skills, and actions.",
            default_file="command_interpretation.md",
        ),
        PromptDefinition(
            id="document_editing",
            title="Document Editing Prompt",
            description="How selected or current document text should be edited.",
            default_file="document_editing.md",
            editable=False,
        ),
        PromptDefinition(
            id="skill_execution",
            title="Skill Execution Prompt",
            description="How loaded procedural skills should guide one turn.",
            default_file="skill_execution.md",
            editable=False,
        ),
        PromptDefinition(
            id="conversational_repair",
            title="Conversational Repair Prompt",
            description="How Jarvis asks for missing context or repairs misunderstandings.",
            default_file="conversational_repair.md",
            editable=False,
        ),
    )

    def __init__(self, app_support_root: Optional[Path] = None) -> None:
        self.app_support_root = Path(app_support_root or self.default_app_support_root()).expanduser()
        self.user_prompts_root = Path(os.environ.get("JARVIS_PROMPTS_HOME", self.app_support_root / "prompts")).expanduser()
        self.default_prompts_root = Path(__file__).resolve().parents[1] / "prompts"
        self.user_prompts_root.mkdir(parents=True, exist_ok=True)
        self._definitions: Dict[str, PromptDefinition] = {definition.id: definition for definition in self.DEFINITIONS}

    @staticmethod
    def default_app_support_root() -> Path:
        if os.environ.get("JARVIS_APP_SUPPORT_HOME"):
            return Path(os.environ["JARVIS_APP_SUPPORT_HOME"])
        if os.environ.get("JARVIS_BRAIN_HOME"):
            return Path(os.environ["JARVIS_BRAIN_HOME"]) / "app_support"
        return Path.home() / "Library" / "Application Support" / "JarvisNotch"

    def list(self, editable_only: bool = False) -> dict:
        definitions: Iterable[PromptDefinition] = self.DEFINITIONS
        if editable_only:
            definitions = [definition for definition in self.DEFINITIONS if definition.editable]
        return {"prompts": [self.get(definition.id) for definition in definitions]}

    def get(self, prompt_id: str) -> dict:
        definition = self._require_definition(prompt_id)
        user_path = self._user_path(definition.id)
        default_path = self._default_path(definition)
        if user_path.exists():
            content = user_path.read_text(encoding="utf-8")
            source = "user"
            path = user_path
        elif default_path and default_path.exists():
            content = default_path.read_text(encoding="utf-8")
            source = "default"
            path = default_path
        else:
            content = definition.default_content
            source = "default"
            path = user_path
        return {
            "id": definition.id,
            "title": definition.title,
            "description": definition.description,
            "content": content,
            "source": source,
            "editable": definition.editable,
            "path": str(path),
        }

    def content(self, prompt_id: str) -> str:
        return str(self.get(prompt_id).get("content") or "")

    def save(self, prompt_id: str, content: str) -> dict:
        definition = self._require_definition(prompt_id)
        if not definition.editable:
            raise PermissionError(f"Prompt '{prompt_id}' is not user editable.")
        path = self._user_path(definition.id)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return self.get(definition.id)

    def save_many(self, prompts: Iterable[dict]) -> dict:
        saved = []
        for prompt in prompts:
            prompt_id = str(prompt.get("id") or "").strip()
            if not prompt_id:
                raise KeyError("Prompt id is required.")
            saved.append(self.save(prompt_id, str(prompt.get("content") or "")))
        return {"prompts": saved}

    def reset(self, prompt_id: str) -> dict:
        definition = self._require_definition(prompt_id)
        if not definition.editable:
            raise PermissionError(f"Prompt '{prompt_id}' is not user editable.")
        path = self._user_path(definition.id)
        if path.exists():
            path.unlink()
        return self.get(definition.id)

    def _require_definition(self, prompt_id: str) -> PromptDefinition:
        definition = self._definitions.get(prompt_id)
        if definition is None:
            raise KeyError(prompt_id)
        return definition

    def _user_path(self, prompt_id: str) -> Path:
        return self.user_prompts_root / f"{prompt_id}.md"

    def _default_path(self, definition: PromptDefinition) -> Optional[Path]:
        if not definition.default_file:
            return None
        return self.default_prompts_root / definition.default_file
