import os
import unittest


class BuildInfoTests(unittest.TestCase):
    def setUp(self):
        for key in [
            "JARVIS_APP_VERSION",
            "JARVIS_APP_BUILD",
            "JARVIS_APP_COMMIT",
            "JARVIS_APP_CHANNEL",
            "JARVIS_UPDATE_CHANNEL",
            "JARVIS_BRAIN_MODE",
        ]:
            os.environ.pop(key, None)

    def tearDown(self):
        self.setUp()

    def test_version_payload_has_required_fields(self):
        from app.build_info import version_payload

        payload = version_payload()
        for key in ["appVersion", "buildNumber", "gitCommit", "brainVersion", "updateChannel", "buildDate"]:
            self.assertIn(key, payload)
        # build number is the canonical incrementing identity.
        self.assertTrue(str(payload["buildNumber"]))

    def test_app_env_overrides_reported_version(self):
        os.environ["JARVIS_APP_VERSION"] = "9.9.9"
        os.environ["JARVIS_APP_BUILD"] = "999"
        os.environ["JARVIS_APP_CHANNEL"] = "beta"
        from app.build_info import version_payload

        payload = version_payload()
        self.assertEqual(payload["appVersion"], "9.9.9")
        self.assertEqual(payload["buildNumber"], "999")
        self.assertEqual(payload["updateChannel"], "beta")

    def test_brain_runtime_reports_mode_and_match(self):
        from app.build_info import brain_runtime, BRAIN_VERSION

        # No app version provided: match is unknown (None), not a false positive.
        self.assertIsNone(brain_runtime()["matchesAppVersion"])

        os.environ["JARVIS_APP_VERSION"] = BRAIN_VERSION
        self.assertTrue(brain_runtime()["matchesAppVersion"])

        os.environ["JARVIS_APP_VERSION"] = "0.0.0-mismatch"
        runtime = brain_runtime()
        self.assertFalse(runtime["matchesAppVersion"])
        self.assertIn(runtime["brainMode"], {"bundled", "developer"})

    def test_status_payload_warns_on_mismatch(self):
        os.environ["JARVIS_APP_VERSION"] = "0.0.0-mismatch"
        from app.build_info import status_payload

        payload = status_payload()
        self.assertTrue(any("does not match" in warning for warning in payload["warnings"]))
        self.assertIn("version", payload)
        self.assertIn("brain", payload)

    def test_runtime_version_and_status_endpoints(self):
        from fastapi.testclient import TestClient
        from app import main

        os.environ.pop("JARVIS_BRAIN_TOKEN", None)
        os.environ["JARVIS_BRAIN_ALLOW_INSECURE"] = "1"
        try:
            client = TestClient(main.app)
            version = client.get("/runtime/version")
            self.assertEqual(version.status_code, 200)
            self.assertIn("appVersion", version.json())
            self.assertIn("brainVersion", version.json())

            status = client.get("/runtime/status")
            self.assertEqual(status.status_code, 200)
            body = status.json()
            # Back-compat fields preserved.
            self.assertIn("providerOrder", body)
            self.assertIn("activeProvider", body)
            # New version dashboard fields.
            self.assertIn("version", body)
            self.assertIn("brain", body)
            self.assertIn("brainMode", body["brain"])
        finally:
            os.environ.pop("JARVIS_BRAIN_ALLOW_INSECURE", None)


if __name__ == "__main__":
    unittest.main()
