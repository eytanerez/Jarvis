#!/usr/bin/env bash
# End-to-end Jarvis release: build -> sign/notarize -> DMG -> appcast.
#
# Usage:
#   scripts/release_update.sh [--channel dev|beta|stable] [--version X.Y.Z] [--no-increment]
#
# Each step degrades gracefully when credentials/tools are missing so local
# development is never blocked, but a real release requires:
#   DEVELOPER_ID_APP, APPLE_ID, APPLE_TEAM_ID, APP_SPECIFIC_PASSWORD,
#   and a Sparkle private key (SPARKLE_PRIVATE_KEY / _FILE).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHANNEL="$(tr -d '[:space:]' < "$ROOT/UPDATE_CHANNEL" 2>/dev/null || echo dev)"
BUILD_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --channel) CHANNEL="$2"; BUILD_ARGS+=(--channel "$2"); shift ;;
    --version) BUILD_ARGS+=(--version "$2"); shift ;;
    --no-increment) BUILD_ARGS+=(--no-increment) ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

echo "############## 1/4 build ##############"
"$ROOT/scripts/build_release.sh" "${BUILD_ARGS[@]}"
APP="$ROOT/build/export/Jarvis.app"

echo "############## 2/4 sign + notarize ##############"
"$ROOT/scripts/notarize.sh" "$APP"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DMG="$ROOT/dist/Jarvis-$VERSION.dmg"

echo "############## 3/4 package DMG ##############"
"$ROOT/scripts/package_dmg.sh" "$APP" "$DMG"

echo "############## 4/4 appcast ($CHANNEL) ##############"
"$ROOT/scripts/generate_appcast.sh" "$CHANNEL" "$DMG"

cat <<EOF

Release prepared for channel '$CHANNEL':
  App:      $APP
  DMG:      $DMG
  Appcast:  Updates/$CHANNEL/appcast.xml

Next:
  1. Create GitHub release v$VERSION and upload $(basename "$DMG").
  2. Commit + push Updates/$CHANNEL/appcast.xml so the feed serves the update.
EOF
