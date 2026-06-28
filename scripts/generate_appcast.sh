#!/usr/bin/env bash
# Generate / update a channel appcast.xml with a Sparkle EdDSA signature for a
# DMG, so installed apps see it as an update.
#
# Usage: scripts/generate_appcast.sh <channel> [path/to/Jarvis-X.Y.Z.dmg]
#
# Key material (never committed):
#   SPARKLE_PRIVATE_KEY     base64 EdDSA private key, OR
#   SPARKLE_PRIVATE_KEY_FILE path to a key file, OR
#   (default) the Jarvis key stored in the login keychain by Sparkle's
#              generate_keys --account Jarvis
#
# Optional:
#   SPARKLE_KEY_ACCOUNT     keychain account when no key file is provided
#                           (default: Jarvis)
#
# The DMG enclosure URL points at the GitHub release for the current VERSION.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL="${1:?usage: generate_appcast.sh <channel> [dmg]}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DMG="${2:-$ROOT/dist/Jarvis-$VERSION.dmg}"
CHANNEL_DIR="$ROOT/Updates/$CHANNEL"
DOWNLOAD_PREFIX="https://github.com/eytanerez/Jarvis/releases/download/v$VERSION/"
SPARKLE_KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-Jarvis}"

if [ ! -f "$DMG" ]; then
  echo "error: DMG not found at $DMG" >&2
  exit 1
fi
mkdir -p "$CHANNEL_DIR"

# Find Sparkle's generate_appcast tool.
find_tool() {
  if [ -n "${SPARKLE_BIN:-}" ] && [ -x "$SPARKLE_BIN/generate_appcast" ]; then
    echo "$SPARKLE_BIN/generate_appcast"; return
  fi
  command -v generate_appcast 2>/dev/null && return
  # Common SwiftPM checkout location under DerivedData.
  local found
  found=$(find "$HOME/Library/Developer/Xcode/DerivedData" "$ROOT/build" -type f -name generate_appcast 2>/dev/null | head -1 || true)
  [ -n "$found" ] && echo "$found"
}

find_keys_tool() {
  if [ -n "${SPARKLE_BIN:-}" ] && [ -x "$SPARKLE_BIN/generate_keys" ]; then
    echo "$SPARKLE_BIN/generate_keys"; return
  fi
  command -v generate_keys 2>/dev/null && return
  local sibling
  sibling="$(dirname "$TOOL")/generate_keys"
  [ -x "$sibling" ] && echo "$sibling" && return
  local found
  found=$(find "$HOME/Library/Developer/Xcode/DerivedData" "$ROOT/build" -type f -name generate_keys 2>/dev/null | head -1 || true)
  [ -n "$found" ] && echo "$found"
}

TOOL="$(find_tool || true)"
if [ -z "$TOOL" ]; then
  echo "Sparkle 'generate_appcast' not found. Skipping appcast generation."
  echo "Install Sparkle tools (e.g. brew install --cask sparkle) or set SPARKLE_BIN,"
  echo "then re-run: scripts/generate_appcast.sh $CHANNEL $DMG"
  exit 0
fi

# Stage only this DMG for the channel so generate_appcast signs it.
cp -f "$DMG" "$CHANNEL_DIR/"

KEY_ARGS=()
KEY_TMP=""
if [ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then
  KEY_ARGS=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
elif [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  KEY_TMP="$(mktemp)"; printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_TMP"
  KEY_ARGS=(--ed-key-file "$KEY_TMP")
else
  KEY_TOOL="$(find_keys_tool || true)"
  if [ -n "$KEY_TOOL" ] && ! "$KEY_TOOL" --account "$SPARKLE_KEY_ACCOUNT" -p >/dev/null 2>&1; then
    echo "Sparkle keychain account '$SPARKLE_KEY_ACCOUNT' was not found. Skipping appcast generation."
    echo "Run generate_keys --account $SPARKLE_KEY_ACCOUNT locally, or provide SPARKLE_PRIVATE_KEY / SPARKLE_PRIVATE_KEY_FILE."
    exit 0
  fi
  KEY_ARGS=(--account "$SPARKLE_KEY_ACCOUNT")
fi
trap '[ -n "$KEY_TMP" ] && rm -f "$KEY_TMP"' EXIT

echo "==> generating appcast for channel '$CHANNEL'"
"$TOOL" "${KEY_ARGS[@]}" \
  --channel "$CHANNEL" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  -o "$CHANNEL_DIR/appcast.xml" \
  "$CHANNEL_DIR"

echo "Updated: $CHANNEL_DIR/appcast.xml"
echo "Enclosure base: $DOWNLOAD_PREFIX"
