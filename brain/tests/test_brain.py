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
            "JARVIS_FILE_INDEX_APPROVED_FOLDERS",
            "JARVIS_FILE_INDEX_EXCLUSIONS",
        ]:
            os.environ.pop(key, None)

    def test_memory_fallback_add_and_search(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            memory = MemoryService()
            memory.add("Calibre uses Apple STT", {"kind": "project"})
            results = memory.search("memory system calibre")
            self.assertTrue(any("Calibre" in item.get("text", "") for item in results))

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

        original = main.tts_service.synthesize
        main.tts_service.synthesize = lambda text, **kwargs: b"RIFFfake"
        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            response = client.post("/tts/synthesize", json={"text": "hello", "engine": "kokoro", "voice": "af_sarah", "speed": 1.0})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers["content-type"], "audio/wav")
            self.assertEqual(response.content, b"RIFFfake")
        finally:
            main.tts_service.synthesize = original
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

    def test_tts_service_routes_chatterbox_lazily(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["JARVIS_BRAIN_HOME"] = directory
            service = TTSService()

            class FakeChatterbox:
                sr = 24000

                def generate(self, text, **kwargs):
                    self.kwargs = kwargs
                    return [0.0, 0.1, 0.0]

            fake = FakeChatterbox()
            service._chatterbox_client = lambda: fake
            service._wav_bytes = lambda samples, sample_rate: b"RIFFchatter"

            audio = service.synthesize(
                "Hello there",
                engine="chatterbox",
                exaggeration=0.7,
                cfg_weight=0.4,
            )
            self.assertEqual(audio, b"RIFFchatter")
            self.assertEqual(fake.kwargs["exaggeration"], 0.7)
            self.assertEqual(fake.kwargs["cfg_weight"], 0.4)


if __name__ == "__main__":
    unittest.main()
