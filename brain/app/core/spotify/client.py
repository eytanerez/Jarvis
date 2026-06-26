from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

SPOTIFY_SCOPES = (
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "playlist-read-private",
    "playlist-modify-private",
    "playlist-modify-public",
    "user-library-read",
    "user-library-modify",
)


class SpotifyCredentialsError(RuntimeError):
    """Raised when a Spotify action is attempted without configured OAuth."""


@dataclass(frozen=True)
class SpotifyConfig:
    client_id: Optional[str] = None
    client_secret: Optional[str] = None
    redirect_uri: Optional[str] = None
    refresh_token: Optional[str] = None

    @property
    def configured(self) -> bool:
        # OAuth requires a client id/secret and a refresh token to act on
        # behalf of the user. Redirect URI is needed only to mint the token.
        return bool(self.client_id and self.client_secret and self.refresh_token)

    def missing(self) -> list[str]:
        missing = []
        if not self.client_id:
            missing.append("SPOTIFY_CLIENT_ID")
        if not self.client_secret:
            missing.append("SPOTIFY_CLIENT_SECRET")
        if not self.refresh_token:
            missing.append("SPOTIFY_REFRESH_TOKEN")
        return missing
