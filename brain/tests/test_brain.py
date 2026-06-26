import asyncio
import json
import os
import tempfile
import unittest
from pathlib import Path

from app.chat_service import ChatService
from app.file_index import FileIndexService
from app.memory_service import MemoryService
from app.runtime_secrets import RuntimeSecrets
from app.tts_service import TTSService
from app.provider_manager import ProviderManager
from app.web_search import WebSearch


class BrainTests(unittest.TestCase):
    def setUp(self):
        for key in [
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "GEMINI_API_KEY",
            "GOOGLE_API_KEY",
            "JARVIS_OPENAI_API_KEY",
            "JARVIS_ANTHROPIC_API_KEY",
            "JARVIS_GEMINI_API_KEY",
            "JARVIS_PROVIDER_ORDER",
            "JARVIS_BRAIN_HOME",
            "JARVIS_FILE_INDEX_ENABLED",
            "JARVIS_FILE_INDEX_MODE",
            "JARVIS_FILE_INDEX_APPROVED_FOLDERS",
            "JARVIS_FILE_INDEX_EXCLUSIONS",
            "JARVIS_FILE_INDEX_MAX_BATCH",
            "JARVIS_FILE_INDEX_MIN_REINDEX_SECONDS",
            "JARVIS_FILE_INDEX_INTERVAL_SECONDS",
            "JARVIS_PERFORMANCE_MODE",
            "JARVIS_TTS_STATUS_TTL_SECONDS",
            "JARVIS_TTS_F5_IDLE_SECONDS",
            "JARVIS_TTS_KOKORO_IDLE_UNLOAD",
            "JARVIS_F5_TTS_DIRECT",
            "JARVIS_F5_TTS_PYTHON",
            "JARVIS_F5_TTS_DEVICE",
            "JARVIS_WEB_SEARCH_MODE",
            "JARVIS_USER_PROFILE_MEMORY_PATH",
            "JARVIS_APP_SUPPORT_HOME",
            "JARVIS_PROMPTS_HOME",
            "JARVIS_SCHEDULED_AGENTS_HOME",
            "JARVIS_SKILLS_HOME",
            "JARVIS_SKILL_BUNDLES_HOME",
            "JARVIS_EXTERNAL_SKILL_DIRS",
        ]:
            os.environ.pop(key, None)
        self._app_support_tmp = tempfile.TemporaryDirectory()
        os.environ["JARVIS_APP_SUPPORT_HOME"] = self._app_support_tmp.name

    def tearDown(self):
        os.environ.pop("JARVIS_APP_SUPPORT_HOME", None)
        os.environ.pop("JARVIS_PROMPTS_HOME", None)
        os.environ.pop("JARVIS_SCHEDULED_AGENTS_HOME", None)
        os.environ.pop("JARVIS_SKILLS_HOME", None)
        os.environ.pop("JARVIS_SKILL_BUNDLES_HOME", None)
        os.environ.pop("JARVIS_EXTERNAL_SKILL_DIRS", None)
        self._app_support_tmp.cleanup()

    def test_memory_fallback_add_and_search(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            memory = MemoryService()
            memory.add("Calibre uses Apple STT", {"kind": "project"})
            results = memory.search("memory system calibre")
            self.assertTrue(any("Calibre" in item.get("text", "") for item in results))

    def test_profile_memory_file_is_searchable(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            profile = Path(directory) / "user_profile_memory.md"
            profile.write_text("Eytan is co-founder and CTO of Calibre.", encoding="utf-8")
            memory = MemoryService()
            results = memory.search("what do you know about me")
            self.assertEqual(results[0]["provider"], "profile_file")
            self.assertIn("Calibre", results[0]["text"])
            self.assertEqual(memory.search("memory system"), [])

    def test_file_index_indexes_only_approved_non_secret_files(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            approved_path = Path(approved)
            (approved_path / "project-notes.md").write_text("Calibre contract notes live here.", encoding="utf-8")
            (approved_path / ".env").write_text("API_KEY=secret", encoding="utf-8")
            (approved_path / "credentials.json").write_text('{"token":"secret"}', encoding="utf-8")

            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            index = FileIndexService()
            status = index.reindex()

            self.assertEqual(status["fileCount"], 1)
            results = index.search("calibre contract")
            self.assertEqual(results[0]["filename"], "project-notes.md")
            self.assertFalse(any(item["filename"] == ".env" for item in results))

            read = index.read(file_id=results[0]["id"], path=None)
            self.assertIn("Calibre contract notes", read["content"])

    def test_web_search_ipad_results(self):
        os.environ["JARVIS_WEB_SEARCH_MODE"] = "demo"
        results = WebSearch().search("top 5 places to buy an iPad", limit=5)
        self.assertEqual(results[2]["name"], "Costco")

    def test_chat_explicit_memory(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            service = ChatService()
            response = asyncio.run(service.chat("Remember that we are using mem0 for memory", None, {}))
            self.assertIn("Got it", response["answer"])
            recall = asyncio.run(service.chat("What do you remember about the memory system?", None, {}))
            self.assertIn("mem0", recall["answer"].lower())

    def test_mode_registry_contains_master_prompt_modes(self):
        from app.core.modes import ModeRegistry

        modes = {item["id"] for item in ModeRegistry().list()}
        self.assertTrue(
            {
                "quick_assistant",
                "dictation",
                "email_writer",
                "document_editor",
                "daily_brief",
                "deep_research",
                "code_helper",
                "focus_monitor",
                "skill_learning",
            }.issubset(modes)
        )

    def test_modes_endpoint_lists_assistant_modes(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            response = client.get("/modes")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["defaultMode"], "quick_assistant")
            mode_ids = {mode["id"] for mode in data["modes"]}
            self.assertIn("dictation", mode_ids)
            self.assertIn("daily_brief", mode_ids)
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_chat_time_routes_through_local_skill_without_provider(self):
        service = ChatService()
        response = asyncio.run(service.chat("What time is it?", None, {}))
        self.assertEqual(response["metadata"]["route"], "local_skill")
        self.assertEqual(response["metadata"]["selectedSkill"], "time.now")
        self.assertEqual(response["metadata"]["trace"]["modelRoute"], "local_skill")
        self.assertIn("skillRunId", response["metadata"])
        history = service.skill_manager.list_history()["runs"]
        self.assertEqual(history[0]["kind"], "local_skill")
        self.assertEqual(history[0]["name"], "time.now")
        self.assertNotIn("What time is it?", json.dumps(history[0]))
        self.assertNotIn("api key", response["answer"].lower())

    def test_open_url_is_yellow_confirmation(self):
        service = ChatService()
        response = asyncio.run(service.chat("Open example.com", None, {}))
        self.assertTrue(response["requiresConfirmation"])
        self.assertEqual(response["confirmation"]["risk"], "yellow")
        self.assertEqual(response["metadata"]["selectedSkill"], "browser.open_url")

    def test_skill_learning_stages_pending_skill(self):
        service = ChatService()
        response = asyncio.run(
            service.chat(
                "/learn Format dealer outreach with a short opener, value prop, and clear next step",
                None,
                {},
            )
        )
        self.assertEqual(response["metadata"]["route"], "skill_learning")
        self.assertEqual(len(response["skillUpdates"]), 1)
        change_id = response["skillUpdates"][0]["id"]
        diff = service.skill_manager.approval.diff(change_id)
        self.assertIn("SKILL.md", diff["diff"])
        approved = service.skill_manager.approve(change_id)
        self.assertTrue(approved["approved"])
        self.assertTrue(any(item["name"] == approved["skillName"] for item in service.skill_manager.list()))

    def test_chat_skill_admin_commands_manage_pending_skill_changes(self):
        service = ChatService()
        learned = asyncio.run(service.chat("/learn Draft investor follow-up with concise bullets", None, {}))
        change_id = learned["skillUpdates"][0]["id"]

        pending = asyncio.run(service.chat("/skills pending", None, {}))
        self.assertEqual(pending["metadata"]["route"], "skill_admin")
        self.assertIn(change_id, pending["answer"])

        diff = asyncio.run(service.chat(f"/skills diff {change_id}", None, {}))
        self.assertIn("```diff", diff["answer"])
        self.assertIn("SKILL.md", diff["answer"])

        approved = asyncio.run(service.chat(f"/skills approve {change_id}", None, {}))
        self.assertEqual(approved["metadata"]["route"], "skill_admin")
        self.assertEqual(approved["skillUpdates"][0]["id"], change_id)
        self.assertTrue(any(item["name"] == approved["skillUpdates"][0]["skillName"] for item in service.skill_manager.list()))

    def test_chat_skill_admin_reject_command_removes_pending_change(self):
        service = ChatService()
        learned = asyncio.run(service.chat("/learn Format a quick launch checklist", None, {}))
        change_id = learned["skillUpdates"][0]["id"]

        rejected = asyncio.run(service.chat(f"/skills reject {change_id}", None, {}))
        self.assertEqual(rejected["metadata"]["route"], "skill_admin")
        self.assertEqual(rejected["skillUpdates"][0]["id"], change_id)
        self.assertEqual(service.skill_manager.approval.pending(), [])

    def test_skill_delete_is_staged_until_approved(self):
        service = ChatService()
        learned = asyncio.run(service.chat("/learn Draft a tiny test skill", None, {}))
        approved = service.skill_manager.approve(learned["skillUpdates"][0]["id"])
        skill_name = approved["skillName"]
        self.assertIsNotNone(service.skill_manager.registry.get(skill_name))

        staged = service.skill_manager.delete(skill_name)
        self.assertFalse(staged["deleted"])
        self.assertTrue(staged["requiresApproval"])
        self.assertEqual(staged["skillUpdate"]["action"], "delete")
        self.assertIsNotNone(service.skill_manager.registry.get(skill_name))

        diff = service.skill_manager.approval.diff(staged["skillUpdate"]["id"])
        self.assertIn("-name:", diff["diff"])

        service.skill_manager.approve(staged["skillUpdate"]["id"])
        self.assertIsNone(service.skill_manager.registry.get(skill_name))

    def test_skill_catalog_progressive_disclosure_and_bundles(self):
        service = ChatService()
        level0 = service.skill_manager.list()
        time_skill = next(item for item in level0 if item["name"] == "time-date")
        self.assertNotIn("body", time_skill)
        level1 = service.skill_manager.view("time-date")
        self.assertIn("body", level1)
        self.assertTrue(any(bundle["name"] == "calibre-launch" for bundle in service.skill_manager.bundles.list()))

    def test_skill_bundle_prepare_loads_only_declared_skills(self):
        service = ChatService()
        prepared = service.skill_manager.prepare_bundle("calibre-launch", query="prep for David meeting")
        loaded = {skill["name"] for skill in prepared["loadedSkills"]}
        self.assertIn("files-search", loaded)
        self.assertIn("document-summarize-current", loaded)
        self.assertIn("email-draft-reply", loaded)
        self.assertEqual(prepared["missingSkills"], [])
        self.assertIn("Keep answers direct", prepared["prompt"])
        self.assertIn("prep for David meeting", prepared["prompt"])
        history = service.skill_manager.list_history()["runs"]
        self.assertEqual(history[0]["kind"], "bundle")
        self.assertEqual(history[0]["name"], "calibre-launch")
        self.assertEqual(history[0]["inputSummary"]["queryLength"], len("prep for David meeting"))
        self.assertNotIn("prep for David meeting", json.dumps(history[0]))

    def test_skill_run_history_records_api_skill_runs_without_private_inputs(self):
        from app.core.skills import SkillManager

        manager = SkillManager()
        result = manager.run("time-date", inputs={"selectedText": "private selected text"})
        self.assertEqual(result["metadata"]["route"], "skill_execution")
        self.assertIn("skillRunId", result["metadata"])

        history = manager.list_history()["runs"]
        self.assertEqual(history[0]["kind"], "skill")
        self.assertEqual(history[0]["name"], "time-date")
        self.assertEqual(history[0]["inputSummary"]["inputKeys"], ["selectedText"])
        self.assertNotIn("private selected text", json.dumps(history[0]))

    def test_chat_slash_invokes_skill_bundle_for_one_turn(self):
        service = ChatService()
        captured = {}

        async def complete(messages, task_type="fast"):
            captured["messages"] = messages
            captured["task_type"] = task_type
            return "Prepared Calibre launch notes."

        service.providers.complete = complete
        response = asyncio.run(service.chat("/calibre-launch prep for David meeting", None, {}))
        self.assertEqual(response["answer"], "Prepared Calibre launch notes.")
        self.assertEqual(response["metadata"]["route"], "skill_bundle")
        self.assertEqual(response["metadata"]["selectedBundle"], "calibre-launch")
        self.assertEqual(response["metadata"]["bundleInvocation"], "slash")
        self.assertEqual(captured["task_type"], "smart")
        self.assertIn("jarvis_bundle_context", captured["messages"][-1]["content"])
        self.assertIn("email-draft-reply", captured["messages"][-1]["content"])

    def test_chat_natural_language_can_invoke_skill_bundle(self):
        service = ChatService()

        async def complete(messages, task_type="fast"):
            return "Natural bundle answer."

        service.providers.complete = complete
        response = asyncio.run(service.chat("Use the Calibre launch workflow to prep this meeting", None, {}))
        self.assertEqual(response["metadata"]["route"], "skill_bundle")
        self.assertEqual(response["metadata"]["bundleInvocation"], "natural_language")

    def test_dictation_cleanup_and_email_format(self):
        from app.dictation import DictationService

        service = DictationService()
        cleaned = service.clean("um can we meet at four pm no three pm on Friday best Moshe")["text"]
        formatted = service.format(cleaned, active_app="Mail")["text"]
        self.assertIn("Best,\nMoshe", formatted)

    def test_prompt_service_loads_defaults_and_saves_user_overrides(self):
        from app.core.prompts import PromptService

        service = PromptService()
        assistant = service.get("assistant")
        self.assertEqual(assistant["source"], "default")
        self.assertIn("natural Mac-native", assistant["content"])

        saved = service.save("assistant", "Use my test assistant prompt.")
        self.assertEqual(saved["source"], "user")
        self.assertEqual(saved["content"], "Use my test assistant prompt.")
        self.assertTrue(Path(saved["path"]).exists())

        reset = service.reset("assistant")
        self.assertEqual(reset["source"], "default")
        self.assertIn("natural Mac-native", reset["content"])

    def test_settings_prompts_endpoint_saves_editable_prompts(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            response = client.get("/settings/prompts")
            self.assertEqual(response.status_code, 200)
            prompt_ids = {prompt["id"] for prompt in response.json()["prompts"]}
            self.assertIn("assistant", prompt_ids)
            self.assertIn("command_interpretation", prompt_ids)

            saved = client.post(
                "/settings/prompts",
                json={"prompts": [{"id": "assistant", "content": "Endpoint prompt override."}]},
            )
            self.assertEqual(saved.status_code, 200)
            self.assertEqual(saved.json()["prompts"][0]["content"], "Endpoint prompt override.")
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_chat_uses_editable_assistant_prompt(self):
        from app.core.prompts import PromptService

        prompts = PromptService()
        prompts.save("assistant", "CUSTOM ASSISTANT PROMPT FOR TESTS.")
        service = ChatService(prompts=prompts)
        captured = {}

        async def complete(messages, task_type="fast"):
            captured["system"] = messages[0]["content"]
            return "Prompt-aware answer."

        service.providers.complete = complete
        response = asyncio.run(service.chat("Tell me something useful", None, {}))
        self.assertEqual(response["answer"], "Prompt-aware answer.")
        self.assertIn("CUSTOM ASSISTANT PROMPT FOR TESTS.", captured["system"])

    def test_capability_registry_reports_unavailable_connectors(self):
        service = ChatService()
        status = service.capability_registry.status()
        capabilities = {item["id"]: item for item in status["available"] + status["unavailable"]}
        self.assertIn("email.search", capabilities)
        self.assertFalse(capabilities["email.search"]["available"])
        self.assertIn("email connector is not connected", capabilities["email.search"]["status_reason"])
        self.assertIn("jarvis.explain_capabilities", capabilities)

    def test_chat_capability_question_is_grounded_without_provider(self):
        service = ChatService()

        async def complete(messages, task_type="fast"):
            raise AssertionError("capability explanation should not call the model")

        service.providers.complete = complete
        response = asyncio.run(service.chat("Can you read my email?", None, {}))
        self.assertEqual(response["metadata"]["route"], "capability_explanation")
        self.assertEqual(response["metadata"]["selectedCapability"], "jarvis.explain_capabilities")
        self.assertIn("email connector is not connected", response["answer"])

    def test_chat_injects_capability_manifest_into_model_prompt(self):
        service = ChatService()
        captured = {}

        async def complete(messages, task_type="fast"):
            captured["system"] = messages[0]["content"]
            return "Capability-aware answer."

        service.providers.complete = complete
        response = asyncio.run(service.chat("Tell me something useful", None, {}))
        self.assertEqual(response["answer"], "Capability-aware answer.")
        self.assertIn("<jarvis_capabilities>", captured["system"])
        self.assertIn("Available now:", captured["system"])
        self.assertIn("Never claim an action happened", captured["system"])

    def test_capabilities_endpoint_explains_live_registry(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            response = client.get("/capabilities")
            self.assertEqual(response.status_code, 200)
            ids = {item["id"] for item in response.json()["available"] + response.json()["unavailable"]}
            self.assertIn("jarvis.explain_capabilities", ids)

            explained = client.post("/capabilities/explain", json={"query": "What can you do?"})
            self.assertEqual(explained.status_code, 200)
            self.assertIn("Drafting is allowed", explained.json()["answer"])
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_scheduled_agent_daily_brief_defaults_disabled_and_previews_sources(self):
        from app.core.scheduled_agents import ScheduledAgentService

        service = ScheduledAgentService()
        daily = service.get("daily_brief")
        self.assertFalse(daily["enabled"])
        self.assertTrue(daily["requiresOptIn"])

        preview = service.preview(
            "daily_brief",
            {
                "schedule": {
                    "calendarAuthorization": "fullAccess",
                    "reminderAuthorization": "fullAccess",
                    "events": [
                        {"title": "Investor check-in", "start": "2026-06-26T14:00:00-04:00"},
                    ],
                    "reminders": [
                        {"title": "Send deck", "start": "2026-06-26T16:00:00-04:00", "completed": False},
                    ],
                }
            },
        )
        self.assertEqual(preview["metadata"]["route"], "scheduled_agent")
        self.assertIn("Investor check-in", preview["answer"])
        self.assertIn("Send deck", preview["answer"])
        self.assertEqual(set(preview["sourcesUsed"]), {"calendar", "reminders"})

        updated = service.update("daily_brief", {"sources": {"reminders": False}})
        self.assertFalse(updated["sources"]["reminders"])
        recorded = service.record_run("daily_brief", "2026-06-26T08:30:00-04:00")
        self.assertEqual(recorded["lastRunAt"], "2026-06-26T08:30:00-04:00")
        self.assertEqual(service.get("daily_brief")["lastRunAt"], "2026-06-26T08:30:00-04:00")
        preview = service.preview(
            "daily_brief",
            {"schedule": {"events": [], "reminders": [{"title": "Hidden reminder", "completed": False}]}},
        )
        self.assertNotIn("Hidden reminder", preview["answer"])

    def test_scheduled_agents_endpoint_updates_and_previews_daily_brief(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            listed = client.get("/scheduled-agents")
            self.assertEqual(listed.status_code, 200)
            self.assertFalse(listed.json()["agents"][0]["enabled"])

            updated = client.post("/scheduled-agents/daily_brief", json={"enabled": True, "time": "07:45"})
            self.assertEqual(updated.status_code, 200)
            self.assertTrue(updated.json()["enabled"])
            self.assertEqual(updated.json()["time"], "07:45")

            preview = client.post(
                "/scheduled-agents/daily_brief/preview",
                json={"schedule": {"events": [{"title": "Morning standup", "start": "2026-06-26T13:00:00Z"}]}},
            )
            self.assertEqual(preview.status_code, 200)
            self.assertIn("Morning standup", preview.json()["answer"])

            recorded = client.post(
                "/scheduled-agents/daily_brief/record-run",
                json={"runAt": "2026-06-26T08:30:00-04:00"},
            )
            self.assertEqual(recorded.status_code, 200)
            self.assertEqual(recorded.json()["lastRunAt"], "2026-06-26T08:30:00-04:00")
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_chat_includes_profile_memory_context(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            profile = Path(directory) / "user_profile_memory.md"
            profile.write_text("Eytan is co-founder and CTO of Calibre.", encoding="utf-8")
            service = ChatService()
            captured = {}

            async def complete(messages, task_type="fast"):
                captured["prompt"] = messages[-1]["content"]
                return "Profile-aware answer."

            service.providers.complete = complete
            response = asyncio.run(service.chat("How should you help me today?", None, {}))
            self.assertEqual(response["answer"], "Profile-aware answer.")
            self.assertIn("userProfileMemory", captured["prompt"])
            self.assertIn("Calibre", captured["prompt"])

    def test_memory_status_reports_json_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            memory = MemoryService()
            memory.add("Local fallback memory", {"kind": "test"})
            status = memory.status()
            self.assertIn(status["activeProvider"], {"json", "mem0"})
            self.assertIn("fallbackPath", status)

    def test_runtime_secrets_reads_gemini_without_openai(self):
        os.environ["JARVIS_PROVIDER_ORDER"] = "gemini,openai"
        os.environ["GEMINI_API_KEY"] = "gemini-secret"
        secrets = RuntimeSecrets.from_environment()
        manager = ProviderManager(secrets=secrets)
        self.assertEqual(manager.enabled_chain(), ["gemini"])
        self.assertEqual(secrets.geminiApiKey, "gemini-secret")
        self.assertIsNone(secrets.openaiApiKey)

    def test_memory_mem0_config_uses_gemini_when_active(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            os.environ["JARVIS_PROVIDER_ORDER"] = "gemini,openai"
            os.environ["GEMINI_API_KEY"] = "gemini-secret"
            memory = MemoryService()
            config = memory._mem0_config()
            self.assertEqual(config["llm"]["provider"], "gemini")
            self.assertEqual(config["embedder"]["provider"], "gemini")
            self.assertEqual(config["llm"]["config"]["api_key"], "gemini-secret")
            self.assertEqual(config["embedder"]["config"]["api_key"], "gemini-secret")
            self.assertNotIn("openai", json.dumps(config).lower())

    def test_memory_status_reports_gemini_debug_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            os.environ["JARVIS_PROVIDER_ORDER"] = "gemini,openai"
            os.environ["GEMINI_API_KEY"] = "gemini-secret"
            memory = MemoryService()
            memory._mem0_checked = True
            memory.last_error = "mem0 unavailable under Gemini"
            status = memory.status()
            self.assertEqual(status["activeModelProvider"], "gemini")
            self.assertTrue(status["geminiKeyConfigured"])
            self.assertTrue(status["brainReceivedGeminiKey"])
            self.assertEqual(status["memoryBackend"], "JSON fallback")
            self.assertEqual(status["fallbackReason"], "mem0 unavailable under Gemini")
            self.assertNotIn("OPENAI_API_KEY", json.dumps(status))

    def test_memory_sanitizes_openai_errors_when_gemini_active(self):
        os.environ["JARVIS_PROVIDER_ORDER"] = "gemini,openai"
        os.environ["GEMINI_API_KEY"] = "gemini-secret"
        memory = MemoryService()
        message = memory._friendly_mem0_error(ValueError("Missing credentials: set OPENAI_API_KEY"))
        self.assertNotIn("OPENAI_API_KEY", message)
        self.assertIn("Gemini", message)

    def test_provider_fallback_does_not_leak_context_wrapper(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            for key in ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY"]:
                os.environ.pop(key, None)
            service = ChatService()
            response = asyncio.run(
                service.chat(
                    "Think through this",
                    {"browser": {"pageText": "private page text"}},
                    {"lastResults": [{"name": "Apple"}]},
                )
            )
            self.assertNotIn("untrusted", response["answer"].lower())
            self.assertNotIn("<untrusted_context>", response["answer"])
            self.assertEqual(response["metadata"]["route"], "missing_provider")

    def test_page_summary_uses_provider_not_truncation(self):
        service = ChatService()

        async def complete(messages, task_type="fast"):
            self.assertEqual(task_type, "fast")
            return "A real model summary."

        service.providers.complete = complete
        response = asyncio.run(
            service.chat(
                "Summarize this page",
                {"browser": {"pageText": "One. Two. Three."}},
                {},
            )
        )
        self.assertEqual(response["answer"], "A real model summary.")
        self.assertTrue(response["metadata"]["usedScreenContext"])

    def test_page_summary_accepts_website_wording(self):
        service = ChatService()
        captured = {}

        async def complete(messages, task_type="fast"):
            captured["prompt"] = messages[-1]["content"]
            return "Website summary."

        service.providers.complete = complete
        response = asyncio.run(
            service.chat(
                "Summarize this website",
                {"browser": {"pageText": "Article lead. Important detail."}},
                {},
                intent="screenContext",
                requires_screen_context=True,
            )
        )
        self.assertEqual(response["answer"], "Website summary.")
        self.assertIn("high-signal bullets", captured["prompt"])
        self.assertTrue(response["metadata"]["usedScreenContext"])

    def test_schedule_context_counts_as_available(self):
        service = ChatService()

        async def complete(messages, task_type="fast"):
            return "You have nothing else coming up."

        service.providers.complete = complete
        response = asyncio.run(
            service.chat(
                "What is on my calendar?",
                {
                    "schedule": {
                        "generatedAt": "2026-06-26T12:00:00Z",
                        "calendarAuthorization": "fullAccess",
                        "reminderAuthorization": "fullAccess",
                        "events": [],
                        "reminders": [],
                    }
                },
                {},
            )
        )
        self.assertEqual(response["answer"], "You have nothing else coming up.")
        self.assertTrue(response["metadata"]["contextAvailable"])

    def test_document_context_counts_as_available(self):
        service = ChatService()
        captured = {}

        async def complete(messages, task_type="fast"):
            captured["prompt"] = messages[-1]["content"]
            return "Use 'That said,' here."

        service.providers.complete = complete
        response = asyncio.run(
            service.chat(
                "What's a good transition word here?",
                {
                    "documentContext": {
                        "appName": "Microsoft Word",
                        "documentTitle": "Essay.docx",
                        "selectedText": "This finding complicates the earlier claim.",
                        "currentParagraph": "This finding complicates the earlier claim.",
                        "previousParagraph": "The earlier evidence seemed straightforward.",
                        "nextParagraph": "The next section turns to limitations.",
                        "textPreview": "The earlier evidence seemed straightforward.\nThis finding complicates the earlier claim.\nThe next section turns to limitations.",
                        "textLength": 132,
                        "source": "microsoft_word",
                    }
                },
                {},
            )
        )
        self.assertEqual(response["answer"], "Use 'That said,' here.")
        self.assertTrue(response["metadata"]["contextAvailable"])
        self.assertIn("Microsoft Word", captured["prompt"])

    def test_reasoning_task_type_for_compare(self):
        service = ChatService()

        async def complete(messages, task_type="fast"):
            return f"task={task_type}"

        service.providers.complete = complete
        response = asyncio.run(service.chat("Compare the first two", None, {"lastResults": [{"name": "A"}]}))
        self.assertEqual(response["answer"], "task=smart")

    def test_openai_stale_model_names_are_normalized(self):
        manager = ProviderManager()
        self.assertEqual(manager._openai_model("gpt-5-mini"), "gpt-5-mini")
        self.assertEqual(manager._openai_model("gpt-5-nano"), "gpt-5-mini")
        self.assertEqual(manager._openai_model("gpt-5.5"), "gpt-5-mini")

    def test_screen_question_without_context_returns_context_missing(self):
        service = ChatService()
        response = asyncio.run(service.chat("What am I looking at?", None, {}))
        self.assertEqual(response["metadata"]["route"], "context_missing")
        self.assertIn("context", response["answer"].lower())

    def test_client_screen_context_flag_overrides_local_detection(self):
        service = ChatService()

        # Flag forces the screen-context check even when the phrase list wouldn't.
        forced = asyncio.run(
            service.chat("tell me about it", None, {}, requires_screen_context=True)
        )
        self.assertEqual(forced["metadata"]["route"], "context_missing")

        # Flag set to False suppresses it even for a phrase the local list matches.
        async def complete(messages, task_type="fast"):
            return "answered"

        service.providers.complete = complete
        suppressed = asyncio.run(
            service.chat("what am i looking at", None, {}, requires_screen_context=False)
        )
        self.assertNotEqual(suppressed["metadata"].get("route"), "context_missing")

    def test_client_intent_web_routes_to_web_branch(self):
        os.environ["JARVIS_WEB_SEARCH_MODE"] = "demo"
        service = ChatService()
        response = asyncio.run(
            service.chat("could you look that up for me", None, {}, intent="web")
        )
        self.assertEqual(response["metadata"]["route"], "web_search")

    def test_provider_diagnostics_records_attempts(self):
        manager = ProviderManager()
        manager._record_attempt("openai", "fast", "gpt-test", False, "Nope")
        report = manager.diagnostics()
        self.assertEqual(report["attempts"][-1]["provider"], "openai")
        self.assertFalse(report["attempts"][-1]["ok"])

    def test_tts_service_caches_short_phrases(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            service = TTSService()
            calls = {"count": 0}

            class FakeKokoro:
                def create(self, text, voice, speed, lang):
                    calls["count"] += 1
                    return [0.0, 0.1, 0.0], 24000

            service._ensure_assets = lambda: None
            service._kokoro_client = lambda: FakeKokoro()
            service._wav_bytes = lambda samples, sample_rate: b"RIFFfake"

            first = service.synthesize("Hello there", "af_sarah", 1.0)
            second = service.synthesize("Hello there", "af_sarah", 1.0)
            self.assertEqual(first, b"RIFFfake")
            self.assertEqual(second, b"RIFFfake")
            self.assertEqual(calls["count"], 1)

    def test_file_index_reindex_search_and_read(self):
        with tempfile.TemporaryDirectory() as directory:
            brain_home = os.path.join(directory, "brain")
            approved = os.path.join(directory, "Documents")
            os.makedirs(approved)
            with open(os.path.join(approved, "contract.md"), "w", encoding="utf-8") as handle:
                handle.write("# Contract\nImportant payment terms.")
            with open(os.path.join(approved, ".env"), "w", encoding="utf-8") as handle:
                handle.write("SECRET=1")
            os.makedirs(os.path.join(approved, "node_modules"))
            with open(os.path.join(approved, "node_modules", "ignored.txt"), "w", encoding="utf-8") as handle:
                handle.write("ignore me")

            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            service = FileIndexService()
            status = service.reindex()
            self.assertEqual(status["fileCount"], 1)
            results = service.search("payment contract")
            self.assertEqual(results[0]["filename"], "contract.md")
            read = service.read(file_id=results[0]["id"])
            self.assertIn("Important payment terms", read["content"])

    def test_chat_routes_file_search_to_local_index(self):
        with tempfile.TemporaryDirectory() as directory:
            brain_home = os.path.join(directory, "brain")
            approved = os.path.join(directory, "Documents")
            os.makedirs(approved)
            with open(os.path.join(approved, "project-notes.md"), "w", encoding="utf-8") as handle:
                handle.write("Jarvis context engine notes")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            service = ChatService()
            service.file_index.reindex()
            response = asyncio.run(service.chat("find project notes file", None, {}))
            self.assertEqual(response["metadata"]["route"], "file_search")
            self.assertIn("project-notes.md", response["answer"])

    def test_tts_endpoint_returns_wav(self):
        from fastapi.testclient import TestClient
        from app import main

        tts = main.container.tts_service
        original = tts.synthesize
        tts.synthesize = lambda text, **kwargs: b"RIFFfake"
        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            response = client.post("/tts/synthesize", json={"text": "hello", "engine": "kokoro", "voice": "af_sarah", "speed": 1.0})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers["content-type"], "audio/wav")
            self.assertEqual(response.content, b"RIFFfake")
        finally:
            tts.synthesize = original
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_auth_fails_closed_without_token(self):
        from app.security import token_is_valid

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)
        # No configured token and no opt-out: deny rather than wave through.
        self.assertFalse(token_is_valid(None))
        self.assertFalse(token_is_valid("anything"))

    def test_auth_allows_insecure_opt_out(self):
        from app.security import token_is_valid

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            self.assertTrue(token_is_valid(None))
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)

    def test_auth_matches_configured_token(self):
        from app.security import token_is_valid

        os.environ["JARVIS_BRAIN_TOKEN"] = "secret-token"
        try:
            self.assertTrue(token_is_valid("secret-token"))
            self.assertFalse(token_is_valid("wrong-token"))
            self.assertFalse(token_is_valid(None))
        finally:
            os.environ.pop("JARVIS_BRAIN_TOKEN", None)

    def test_tts_service_routes_f5_lazily(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            service = TTSService()

            class FakeF5:
                def infer(self, **kwargs):
                    self.kwargs = kwargs
                    return [0.0, 0.1, 0.0], 24000, None

            fake = FakeF5()
            service._f5_client = lambda: fake
            service._default_f5_reference_audio = lambda: "/tmp/reference.wav"
            service._wav_bytes = lambda samples, sample_rate: b"RIFFf5"

            audio = service.synthesize(
                "Hello there",
                engine="f5tts",
                reference_text="Reference words.",
                cfg_strength=2.4,
                nfe_step=40,
            )
            self.assertEqual(audio, b"RIFFf5")
            self.assertEqual(fake.kwargs["ref_text"], "Reference words.")
            self.assertEqual(fake.kwargs["cfg_strength"], 2.4)
            self.assertEqual(fake.kwargs["nfe_step"], 40)


    # -- Priority 1: file indexer ------------------------------------------

    def test_file_index_default_mode_is_manual_with_status_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            index = FileIndexService()
            self.assertEqual(index.mode, "manual")
            status = index.status()
            for key in [
                "indexingMode",
                "lastFullReindexAt",
                "lastIncrementalScanAt",
                "currentFile",
                "filesScannedThisRun",
                "filesSkippedThisRun",
            ]:
                self.assertIn(key, status)
            self.assertEqual(status["indexingMode"], "manual")

    def test_file_index_off_mode_does_not_scan(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            (Path(approved) / "notes.md").write_text("hello world", encoding="utf-8")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            os.environ["JARVIS_FILE_INDEX_MODE"] = "off"
            index = FileIndexService()
            self.assertFalse(index.enabled)
            status = index.reindex()
            self.assertEqual(status["fileCount"], 0)

    def test_file_index_respects_max_batch(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            for i in range(5):
                (Path(approved) / f"file{i}.md").write_text(f"content {i}", encoding="utf-8")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            os.environ["JARVIS_FILE_INDEX_MAX_BATCH"] = "2"
            index = FileIndexService()
            status = index.reindex()
            self.assertLessEqual(status["filesScannedThisRun"], 2)
            self.assertLessEqual(status["fileCount"], 2)

    def test_file_index_incremental_skips_unchanged(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            (Path(approved) / "a.md").write_text("alpha notes", encoding="utf-8")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            index = FileIndexService()
            index.reindex()
            status = index.incremental_scan()
            self.assertEqual(status["fileCount"], 1)
            self.assertEqual(status["filesScannedThisRun"], 0)
            self.assertGreaterEqual(status["filesSkippedThisRun"], 1)
            self.assertIsNotNone(status["lastIncrementalScanAt"])

    def test_file_index_incremental_prunes_deleted(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            a = Path(approved) / "a.md"
            b = Path(approved) / "b.md"
            a.write_text("alpha", encoding="utf-8")
            b.write_text("beta", encoding="utf-8")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            index = FileIndexService()
            self.assertEqual(index.reindex()["fileCount"], 2)
            b.unlink()
            self.assertEqual(index.incremental_scan()["fileCount"], 1)

    def test_file_index_watcher_full_reindex_throttled(self):
        with tempfile.TemporaryDirectory(dir=str(Path.home())) as brain_home, tempfile.TemporaryDirectory(dir=str(Path.home())) as approved:
            (Path(approved) / "a.md").write_text("alpha", encoding="utf-8")
            os.environ["JARVIS_BRAIN_HOME"] = brain_home
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = approved
            index = FileIndexService()
            index.reindex(source="watcher")
            (Path(approved) / "b.md").write_text("beta", encoding="utf-8")
            # A watcher-driven full reindex is throttled within the 15 min window.
            index.reindex(source="watcher")
            self.assertEqual(index.status()["fileCount"], 1)
            # A user-driven reindex always runs.
            index.reindex(source="user")
            self.assertEqual(index.status()["fileCount"], 2)

    # -- Priority 2/5: shared, lazy container ------------------------------

    def test_service_container_shares_services(self):
        from app.core import ServiceContainer

        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            container = ServiceContainer()
            self.assertIs(container.chat_service.file_index, container.file_index_service)
            self.assertIs(container.chat_service.memory, container.memory_service)
            self.assertIs(container.chat_service.providers, container.provider_manager)
            self.assertIs(container.chat_service.web, container.web_search)

    def test_service_container_is_lazy(self):
        from app.core import ServiceContainer

        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            container = ServiceContainer()
            self.assertIsNone(container._tts_service)
            self.assertIsNone(container._file_index_service)
            self.assertIsNone(container._chat_service)
            _ = container.file_index_service
            self.assertIsNotNone(container._file_index_service)
            self.assertIsNone(container._tts_service)

    # -- Priority 3: cached TTS status -------------------------------------

    def test_tts_status_caches_f5_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            service = TTSService()
            calls = {"count": 0}

            def fake_probe():
                calls["count"] += 1
                return {"importable": False, "device": None}

            service._f5_status = fake_probe
            service._kokoro_importable = lambda: False
            service.status()
            service.status()
            self.assertEqual(calls["count"], 1)
            service.status(force_refresh=True)
            self.assertEqual(calls["count"], 2)

    # -- Priority 6: performance modes -------------------------------------

    def test_performance_settings_modes(self):
        from app.core import PerformanceSettings

        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            perf = PerformanceSettings()
            self.assertEqual(perf.mode, "balanced")
            self.assertEqual(perf.file_index_default_mode, "manual")
            perf.set_mode("performance")
            self.assertEqual(perf.file_index_default_mode, "off")
            self.assertFalse(perf.memory_suggestions)
            self.assertTrue(perf.shortest_spoken_responses)
            perf.set_mode("full_context")
            self.assertEqual(perf.file_index_default_mode, "incremental")
            self.assertTrue(perf.memory_suggestions)
            # Persisted across instances.
            self.assertEqual(PerformanceSettings().mode, "full_context")
            with self.assertRaises(ValueError):
                perf.set_mode("nonsense")

    def test_performance_mode_disables_memory_suggestions(self):
        from app.core import PerformanceSettings

        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            os.environ["JARVIS_PERFORMANCE_MODE"] = "performance"
            perf = PerformanceSettings()
            service = ChatService(performance=perf)
            service.memory.add("User loves espresso", {"kind": "preferences"})
            self.assertEqual(service._relevant_memories("coffee"), [])

    # -- Priority 7: dashboard ---------------------------------------------

    def test_dashboard_endpoint_is_light(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            self.assertEqual(client.get("/health").status_code, 200)
            response = client.get("/runtime/dashboard")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            for key in ["performanceMode", "fileIndex", "tts", "providers", "chat", "backgroundServices"]:
                self.assertIn(key, data)
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)


if __name__ == "__main__":
    unittest.main()
