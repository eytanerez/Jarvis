from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

from ..catalog import SkillCatalogGenerator
from ..catalog.definitions import CATALOG
from .approval import SkillApprovalStore
from .bundles import SkillBundleStore
from .catalog import SkillCatalog
from .executor import SkillExecutor
from .history import SkillRunHistory
from .learner import SkillLearner
from .loader import SkillLoader
from .matcher import SkillMatcher
from .registry import SkillRegistry
from .security import SkillSecurity


# Hidden working directories the registry skips when loading skills.
SKILL_WORK_DIRS = [".hub", ".pending", ".audit"]

# Folder categories the catalog manages, plus the working dirs. Built from the
# canonical catalog so the layout always matches the single source of truth.
SKILL_CATEGORIES = sorted({defn.category for defn in CATALOG}) + SKILL_WORK_DIRS


class SkillManager:
    def __init__(self, app_support_root: Optional[Path] = None) -> None:
        root = app_support_root or self.default_app_support_root()
        self.app_support_root = Path(root).expanduser()
        self.skills_root = Path(os.environ.get("JARVIS_SKILLS_HOME", self.app_support_root / "skills")).expanduser()
        self.bundles_root = Path(os.environ.get("JARVIS_SKILL_BUNDLES_HOME", self.app_support_root / "skill-bundles")).expanduser()
        self.security = SkillSecurity()
        self.loader = SkillLoader(self.security)
        self.generator = SkillCatalogGenerator(self.skills_root)
        self._ensure_layout()
        self.catalog_status = self.generator.ensure()
        self._ensure_starter_bundle()
        external = [Path(item).expanduser() for item in os.environ.get("JARVIS_EXTERNAL_SKILL_DIRS", "").split(os.pathsep) if item.strip()]
        self.registry = SkillRegistry([self.skills_root, *external], loader=self.loader)
        self.catalog = SkillCatalog(self.registry)
        self.matcher = SkillMatcher(self.registry)
        self.executor = SkillExecutor()
        self.approval = SkillApprovalStore(self.skills_root / ".pending", self.skills_root)
        self.history = SkillRunHistory(self.skills_root / ".audit")
        self.learner = SkillLearner(self.approval, self.security)
        self.bundles = SkillBundleStore(self.bundles_root)

    @staticmethod
    def default_app_support_root() -> Path:
        if os.environ.get("JARVIS_APP_SUPPORT_HOME"):
            return Path(os.environ["JARVIS_APP_SUPPORT_HOME"])
        if os.environ.get("JARVIS_BRAIN_HOME"):
            return Path(os.environ["JARVIS_BRAIN_HOME"]) / "app_support"
        return Path.home() / "Library" / "Application Support" / "JarvisNotch"

    def list(self) -> list[dict]:
        self.registry.reload()
        return self.catalog.skills_list()

    def view(self, name: str, path: Optional[str] = None) -> Dict[str, Any]:
        self.registry.reload()
        return self.catalog.skill_view(name, path)

    def search(self, query: str, mode: str = "quick_assistant") -> list[dict]:
        self.registry.reload()
        return self.matcher.candidates(query, mode)

    def run(self, name: str, inputs: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        self.registry.reload()
        skill = self.registry.get(name)
        if skill is None:
            raise KeyError(name)
        result = self.executor.run(skill, inputs)
        run = self.history.record(
            kind="skill",
            name=skill.name,
            route="skill_execution",
            status="requires_confirmation" if result.get("requiresConfirmation") else "prepared",
            risk_level=skill.metadata.risk_level,
            requires_confirmation=bool(result.get("requiresConfirmation")),
            warnings=skill.warnings,
            input_summary=self._input_summary(inputs or {}),
            metadata=result.get("metadata") or {},
        )
        result.setdefault("metadata", {})["skillRunId"] = run["id"]
        return result

    def bundle_invocation(self, message: str) -> Optional[Dict[str, Any]]:
        return self.bundles.match_invocation(message)

    def prepare_bundle(self, name: str, query: str = "", record_history: bool = True) -> Dict[str, Any]:
        self.registry.reload()
        bundle = self.bundles.get(name)
        if bundle is None:
            raise KeyError(name)
        loaded = []
        missing = []
        warnings = []
        for skill_name in bundle.get("skills") or []:
            skill = self.registry.get(str(skill_name))
            if skill is None:
                missing.append(str(skill_name))
                continue
            loaded.append(skill.level1())
            warnings.extend(skill.warnings)
        if missing:
            warnings.append("Missing bundled skills were skipped: " + ", ".join(missing))
        result = {
            "bundle": bundle,
            "query": query,
            "loadedSkills": loaded,
            "missingSkills": missing,
            "warnings": warnings,
            "prompt": self._bundle_prompt(bundle, query, loaded, missing),
        }
        if record_history:
            run = self.history.record(
                kind="bundle",
                name=str(bundle.get("name") or name),
                route="skill_bundle_prepare",
                status="prepared",
                loaded_skills=[skill.get("name", "") for skill in loaded if skill.get("name")],
                missing_skills=missing,
                warnings=warnings,
                input_summary={"queryLength": len(query or "")},
                metadata={"selectedBundle": bundle.get("name")},
            )
            result["runId"] = run["id"]
        return result

    def learn(self, source: str, name: Optional[str] = None, category: str = "personal", description: Optional[str] = None, mode: str = "quick_assistant") -> Dict[str, Any]:
        result = self.learner.draft(source, name=name, category=category, description=description, mode=mode)
        self.registry.reload()
        return result

    def approve(self, change_id: str) -> Dict[str, Any]:
        result = self.approval.approve(change_id)
        self.registry.reload()
        return result

    def reject(self, change_id: str) -> Dict[str, Any]:
        return self.approval.reject(change_id)

    def list_history(self, limit: int = 50) -> Dict[str, Any]:
        return self.history.list(limit=limit)

    def record_response_run(self, payload: Dict[str, Any], metadata: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        selected = metadata.get("selectedSkill")
        route = metadata.get("route")
        if not selected or route not in {"local_skill", "skill_execution", "skill_bundle", "skill_learning"}:
            return None
        name = str(selected)
        kind = "skill"
        if route == "local_skill":
            kind = "local_skill"
        elif route == "skill_bundle":
            kind = "bundle"
            name = str(metadata.get("selectedBundle") or name.removeprefix("bundle:"))
        status = "requires_confirmation" if payload.get("requiresConfirmation") else "completed"
        return self.history.record(
            kind=kind,
            name=name,
            route=str(route),
            status=status,
            mode=metadata.get("mode"),
            intent=metadata.get("intent"),
            risk_level=metadata.get("riskLevel"),
            requires_confirmation=bool(payload.get("requiresConfirmation")),
            loaded_skills=metadata.get("loadedSkills") or [],
            missing_skills=metadata.get("missingSkills") or [],
            warnings=metadata.get("warnings") or [],
            input_summary=self._response_input_summary(payload, metadata),
            metadata=metadata,
        )

    def delete(self, name: str) -> Dict[str, Any]:
        skill = self.registry.get(name)
        if skill is None:
            raise KeyError(name)
        root = skill.path.parent
        change = self.approval.stage_delete(
            skill.metadata.name,
            root,
            summary=f"Delete skill {skill.metadata.name}.",
            warnings=skill.warnings,
        )
        return {
            "deleted": False,
            "requiresApproval": True,
            "skillUpdate": change.to_dict(),
            "name": skill.metadata.name,
        }

    def config(self) -> Dict[str, Any]:
        return {
            "skills": {
                "enabled": True,
                "writeApproval": True,
                "externalDirs": [item for item in os.environ.get("JARVIS_EXTERNAL_SKILL_DIRS", "").split(os.pathsep) if item],
                "allowGitHubSkillInstall": False,
                "allowRemoteSkillInstall": False,
                "root": str(self.skills_root),
                "bundlesRoot": str(self.bundles_root),
                "catalog": dict(self.catalog_status),
                "duplicateWarnings": list(self.registry.duplicate_warnings),
            }
        }

    def _bundle_prompt(
        self,
        bundle: Dict[str, Any],
        query: str,
        loaded: list[Dict[str, Any]],
        missing: list[str],
    ) -> str:
        skill_sections = []
        for skill in loaded:
            name = skill.get("name", "unknown-skill")
            raw = skill.get("raw") or skill.get("body") or ""
            skill_sections.append(f"## Skill: {name}\n{raw[:12000]}")
        missing_text = ", ".join(missing) if missing else "none"
        return (
            "Jarvis skill bundle for this turn only.\n"
            f"Bundle: {bundle.get('name')}\n"
            f"Description: {bundle.get('description')}\n"
            f"Instruction: {bundle.get('instruction')}\n"
            f"User request inside bundle: {query or '(none provided)'}\n"
            f"Missing skills skipped: {missing_text}\n\n"
            "Use the loaded skills as procedural guidance. Do not claim actions happened unless app action results say they happened. "
            "Ask one specific question if required inputs are missing. Keep the response aligned with the bundle instruction.\n\n"
            + "\n\n".join(skill_sections)
        )

    def duplicate_warnings(self) -> list[str]:
        self.registry.reload()
        return list(self.registry.duplicate_warnings)

    def _ensure_layout(self) -> None:
        for category in SKILL_CATEGORIES:
            (self.skills_root / category).mkdir(parents=True, exist_ok=True)
        self.bundles_root.mkdir(parents=True, exist_ok=True)

    def _ensure_starter_bundle(self) -> None:
        bundle = self.bundles_root / "calibre-launch.yaml"
        if not bundle.exists():
            bundle.write_text(
                "name: calibre-launch\n"
                "description: Calibre launch planning workflow\n"
                "skills:\n"
                "  - files-search\n"
                "  - document-summarize-current\n"
                "  - email-draft-reply\n"
                "instruction: |\n"
                "  Keep answers direct, practical, and investor-ready.\n",
                encoding="utf-8",
            )

    def _input_summary(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "inputKeys": sorted(str(key) for key in inputs.keys()),
            "hasContext": "context" in inputs or "schedule" in inputs,
        }

    def _response_input_summary(self, payload: Dict[str, Any], metadata: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "actionCount": len(payload.get("actions") or []),
            "resultCount": len(payload.get("results") or []),
            "contextAvailable": bool(metadata.get("contextAvailable")),
        }
