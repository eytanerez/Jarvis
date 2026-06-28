#!/usr/bin/env bash
# Sign (Developer ID, hardened runtime), notarize, and staple a Jarvis.app.
#
# Usage: scripts/notarize.sh [path/to/Jarvis.app]
#
# Required env (skips gracefully with a clear message when missing):
#   DEVELOPER_ID_APP   "Developer ID Application: Name (TEAMID)"
#   APPLE_ID           Apple ID email for notarytool
#   APPLE_TEAM_ID      10-char team id
#   APP_SPECIFIC_PASSWORD  app-specific password for the Apple ID
# Optional:
#   ENTITLEMENTS       path to entitlements plist (default: Atoll/DynamicIsland/DynamicIsland.entitlements)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/export/Jarvis.app}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT/Atoll/DynamicIsland/DynamicIsland.entitlements}"

if [ ! -d "$APP" ]; then
  echo "error: app not found at $APP" >&2
  exit 1
fi

missing=0
for var in DEVELOPER_ID_APP APPLE_ID APPLE_TEAM_ID APP_SPECIFIC_PASSWORD; do
  if [ -z "${!var:-}" ]; then echo "missing env: $var"; missing=1; fi
done
if [ "$missing" = "1" ]; then
  echo ""
  echo "Notarization credentials are not configured. Skipping signing/notarization."
  echo "The app remains usable locally but cannot be distributed as a release."
  exit 0
fi

echo "==> codesign (hardened runtime, deep) with: $DEVELOPER_ID_APP"
SIGN_ARGS=(--force --options runtime --timestamp --sign "$DEVELOPER_ID_APP")
[ -f "$ENTITLEMENTS" ] && SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
# Sign nested code first (frameworks, XPC, helpers), then the app.
find "$APP/Contents/Frameworks" -type d \( -name "*.framework" -o -name "*.xpc" -o -name "*.app" \) 2>/dev/null \
  | while read -r nested; do codesign "${SIGN_ARGS[@]}" "$nested" || true; done
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="$(dirname "$APP")/Jarvis-notarize.zip"
echo "==> zipping for notarization"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "==> stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
echo "Notarized + stapled: $APP"
