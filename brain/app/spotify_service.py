from __future__ import annotations

from typing import Any, Dict, Optional

from .core.spotify import SpotifyConfig, SpotifyCredentialsError


class SpotifyService:
    """Spotify integration over OAuth.

    Holds no plaintext secrets in skills: credentials come from runtime secrets
    only. ``status()`` reports configured/connected without exposing tokens.
    Playback and library mutations are returned as structured actions; the
    risk/confirmation gate lives in the catalog + Swift side.
    """

    def __init__(self, secrets: Optional[Any] = None) -> None:
        self._secrets = secrets
        # None = untested, True/False = last connection test result.
        self._connection_ok: Optional[bool] = None
        self._last_error: str = ""

    def _config(self) -> SpotifyConfig:
        secrets = self._secrets
        return SpotifyConfig(
            client_id=getattr(secrets, "spotifyClientId", None),
            client_secret=getattr(secrets, "spotifyClientSecret", None),
            redirect_uri=getattr(secrets, "spotifyRedirectUri", None),
            refresh_token=getattr(secrets, "spotifyRefreshToken", None),
        )

    @property
    def configured(self) -> bool:
        return self._config().configured

    @property
    def connected(self) -> bool:
        # Available once credentials are present and no test has failed.
        return self.configured and self._connection_ok is not False

    def status(self) -> Dict[str, Any]:
        config = self._config()
        configured = config.configured
        connected = self.connected
        if not configured:
            reason = "Spotify is not connected; add " + ", ".join(config.missing()) + " in Settings"
        elif self._connection_ok is False:
            reason = self._last_error or "Spotify connection test failed; re-authorize Spotify"
        else:
            reason = ""
        return {
            "configured": configured,
            "connected": connected,
            "reason": reason,
            "redirectUriSet": bool(config.redirect_uri),
            "lastTest": self._connection_ok,
            # Never expose token values.
            "secretsPresent": {
                "clientId": bool(config.client_id),
                "clientSecret": bool(config.client_secret),
                "refreshToken": bool(config.refresh_token),
            },
        }

    def test(self) -> Dict[str, Any]:
        """Validate that credentials are present and (when wired) that a token
        refresh succeeds. The live HTTP refresh is not performed in this
        scaffold; a real transport should set ``_connection_ok`` accordingly."""
        config = self._config()
        if not config.configured:
            self._connection_ok = False
            self._last_error = "Missing Spotify credentials: " + ", ".join(config.missing())
            return {"ok": False, "reason": self._last_error, "missing": config.missing()}
        # Credentials present. A real implementation refreshes the OAuth token
        # here and sets _connection_ok based on the result.
        self._connection_ok = True
        self._last_error = ""
        return {"ok": True, "reason": "", "note": "Credentials present. Live token refresh not performed in scaffold."}

    def require_connected(self) -> None:
        if not self.connected:
            raise SpotifyCredentialsError(self.status()["reason"])

    def build_action(self, action_type: str, payload: Dict[str, Any], *, risk: str = "yellow") -> Dict[str, Any]:
        """Return a structured Spotify action for the Mac app to execute."""
        action = {"id": f"spotify_{action_type}", "type": f"spotify_{action_type}", "payload": dict(payload)}
        requires_confirmation = risk in {"yellow", "red"}
        result: Dict[str, Any] = {"action": action, "requiresConfirmation": requires_confirmation, "risk": risk}
        if requires_confirmation:
            result["confirmation"] = {
                "id": f"confirm_spotify_{action_type}",
                "risk": risk,
                "title": f"Spotify: {action_type.replace('_', ' ')}?",
                "action": action,
            }
        return result
