"""Spotify Web API scaffolding.

OAuth-based access only. Secrets (client id/secret, refresh token) live in
runtime secrets / keychain-backed storage and are never read from skills or
returned by status. Until credentials are configured and a connection test
passes, Spotify capabilities report unavailable.
"""

from .client import SpotifyConfig, SpotifyCredentialsError

__all__ = ["SpotifyConfig", "SpotifyCredentialsError"]
