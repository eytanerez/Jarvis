import os
import tempfile
import unittest
from pathlib import Path

from app.core.capabilities import CAPABILITY_CATEGORIES
from app.core.catalog import (
    CATALOG,
    AvailabilityContext,
    build_context,
    catalog_capabilities,
    catalog_index,
    run_self_test,
)
from app.core.catalog.availability import resolve_availability
from app.core.skills import SkillManager


class _FakeSpotify:
    def __init__(self, connected: bool) -> None:
        self._connected = connected

    def status(self) -> dict:
        return {
            "configured": self._connected,
            "connected": self._connected,
            "reason": "" if self._connected else "Spotify is not connected; add credentials",
        }


class _FakeAtoll:
    def __init__(self, areas: dict) -> None:
        self._areas = areas

    def status(self) -> dict:
        return dict(self._areas)


class CatalogInvariantTests(unittest.TestCase):
    """Catalog-level invariants that don't need disk or services."""

    def test_self_test_passes(self):
        result = run_self_test()
        self.assertTrue(result["ok"], result["issues"])
        self.assertEqual(result["duplicateNames"], [])

    def test_every_skill_has_unique_name(self):
        names = [defn.name for defn in CATALOG]
        self.assertEqual(len(names), len(set(names)))

    def test_every_capability_id_is_unique_and_matches_path(self):
        ids = [defn.capability_id for defn in CATALOG]
        self.assertEqual(len(ids), len(set(ids)))
        for defn in CATALOG:
            self.assertEqual(defn.capability_id, f"{defn.category}.{defn.name}")

    def test_every_skill_has_a_matching_capability(self):
        caps = {cap.id for cap in catalog_capabilities(AvailabilityContext())}
        for defn in CATALOG:
            self.assertIn(defn.capability_id, caps)

    def test_every_reusable_capability_has_a_matching_skill(self):
        index = catalog_index()
        for cap in catalog_capabilities(AvailabilityContext()):
            self.assertIn(cap.id, index)

    def test_red_skills_require_confirmation(self):
        for defn in CATALOG:
            if defn.risk_level == "red":
                self.assertTrue(defn.requires_confirmation, defn.path)

    def test_yellow_skills_require_confirmation_and_green_do_not(self):
        for defn in CATALOG:
            if defn.risk_level == "yellow":
                self.assertTrue(defn.requires_confirmation, defn.path)
            if defn.risk_level == "green":
                self.assertFalse(defn.requires_confirmation, defn.path)

    def test_capability_categories_include_new_areas(self):
        for category in ["clock", "contacts", "phone", "media", "spotify", "notes", "workspace"]:
            self.assertIn(category, CAPABILITY_CATEGORIES)


class CatalogAvailabilityTests(unittest.TestCase):
    def test_unavailable_atoll_and_spotify_are_not_advertised(self):
        caps = {cap.id: cap for cap in catalog_capabilities(AvailabilityContext())}
        for cap_id in ["calendar.calendar-today", "clock.timer-start", "spotify.spotify-play-track", "phone.call-contact"]:
            self.assertFalse(caps[cap_id].available, cap_id)
            self.assertTrue(caps[cap_id].status_reason, cap_id)

    def test_play_spotify_unavailable_until_configured(self):
        defn = catalog_index()["spotify.spotify-play-track"]
        off = build_context(spotify=_FakeSpotify(False))
        available, reason = resolve_availability(defn, off)
        self.assertFalse(available)
        self.assertIn("Spotify", reason)

        on = build_context(spotify=_FakeSpotify(True))
        available, _ = resolve_availability(defn, on)
        self.assertTrue(available)

    def test_call_contact_is_red_confirmation(self):
        defn = catalog_index()["phone.call-contact"]
        self.assertEqual(defn.risk_level, "red")
        self.assertTrue(defn.requires_confirmation)

    def test_send_message_is_red_confirmation(self):
        defn = catalog_index()["messages.message-send-confirmed"]
        self.assertEqual(defn.risk_level, "red")
        self.assertTrue(defn.requires_confirmation)

    def test_start_a_timer_depends_on_atoll_clock_status(self):
        defn = catalog_index()["clock.timer-start"]
        off = build_context(atoll=_FakeAtoll({}))
        self.assertFalse(resolve_availability(defn, off)[0])

        on = build_context(atoll=_FakeAtoll({"clock": {"available": True, "read": True, "write": True}}))
        self.assertTrue(resolve_availability(defn, on)[0])

    def test_atoll_read_only_blocks_writes_but_allows_reads(self):
        read_only = build_context(atoll=_FakeAtoll({"calendar": {"available": True, "read": True, "write": False}}))
        today = catalog_index()["calendar.calendar-today"]
        create = catalog_index()["calendar.calendar-create-event"]
        self.assertTrue(resolve_availability(today, read_only)[0])
        self.assertFalse(resolve_availability(create, read_only)[0])

    def test_spotify_status_never_exposes_tokens(self):
        from app.spotify_service import SpotifyService
        from app.runtime_secrets import RuntimeSecrets

        secrets = RuntimeSecrets.from_environment(
            {
                "SPOTIFY_CLIENT_ID": "id-value",
                "SPOTIFY_CLIENT_SECRET": "secret-value",
                "SPOTIFY_REFRESH_TOKEN": "token-value",
            }
        )
        status = SpotifyService(secrets=secrets).status()
        import json

        blob = json.dumps(status)
        self.assertNotIn("id-value", blob)
        self.assertNotIn("secret-value", blob)
        self.assertNotIn("token-value", blob)
        self.assertTrue(status["configured"])
        self.assertTrue(status["secretsPresent"]["refreshToken"])


class CatalogSkillFileTests(unittest.TestCase):
    def setUp(self):
        for key in ["JARVIS_SKILLS_HOME", "JARVIS_SKILL_BUNDLES_HOME", "JARVIS_EXTERNAL_SKILL_DIRS"]:
            os.environ.pop(key, None)
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["JARVIS_APP_SUPPORT_HOME"] = self._tmp.name

    def tearDown(self):
        os.environ.pop("JARVIS_APP_SUPPORT_HOME", None)
        os.environ.pop("JARVIS_EXTERNAL_SKILL_DIRS", None)
        self._tmp.cleanup()

    def test_all_catalog_skills_appear_in_skill_list_without_duplicates(self):
        manager = SkillManager()
        names = {item["name"] for item in manager.list()}
        for defn in CATALOG:
            self.assertIn(defn.name, names)
        self.assertEqual(manager.duplicate_warnings(), [])

    def test_generated_skill_md_has_canonical_sections(self):
        manager = SkillManager()
        view = manager.view("calendar-create-event")
        for section in [
            "## When to Use",
            "## Inputs Needed",
            "## Procedure",
            "## Safety and Confirmation",
            "## Pitfalls",
            "## Verification",
            "## Response Style",
        ]:
            self.assertIn(section, view["body"])
        self.assertEqual(view["source"], "atoll_apple_bridge")
        self.assertEqual(view["capabilityId"], "calendar.calendar-create-event")

    def test_duplicate_skill_name_across_folders_is_warned(self):
        external_root = Path(self._tmp.name) / "external"
        dup_dir = external_root / "shadow-calendar-today"
        dup_dir.mkdir(parents=True)
        (dup_dir / "SKILL.md").write_text(
            "---\nname: calendar-today\ndescription: shadow copy\ncategory: calendar\n---\n\nbody\n",
            encoding="utf-8",
        )
        os.environ["JARVIS_EXTERNAL_SKILL_DIRS"] = str(external_root)
        manager = SkillManager()
        warnings = manager.duplicate_warnings()
        self.assertTrue(any("calendar-today" in warning for warning in warnings), warnings)


if __name__ == "__main__":
    unittest.main()
