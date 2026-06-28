#!/usr/bin/env bash
# Package Jarvis.app into a distributable DMG with an /Applications symlink so
# first install is a simple drag-and-drop.
#
# Usage: scripts/package_dmg.sh [path/to/Jarvis.app] [output.dmg]
#
# Optional env:
#   DEVELOPER_ID_APP   when set, the DMG is also codesigned.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/export/Jarvis.app}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || echo 0.0.0)"
DIST_DIR="$ROOT/dist"
DMG="${2:-$DIST_DIR/Jarvis-$VERSION.dmg}"

if [ ! -d "$APP" ]; then
  echo "error: app not found at $APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> staging DMG contents"
cp -R "$APP" "$STAGE/Jarvis.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Install Jarvis.txt" <<EOF
Drag Jarvis into the Applications folder, then launch it from /Applications.

Do not run Jarvis directly from this disk image — updates only work from
/Applications/Jarvis.app.
EOF

rm -f "$DMG"
echo "==> creating DMG: $DMG"
hdiutil create -volname "Jarvis $VERSION" \
  -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> codesigning DMG"
  codesign --force --timestamp --sign "$DEVELOPER_ID_APP" "$DMG"
fi

SIZE=$(stat -f%z "$DMG" 2>/dev/null || echo 0)
echo ""
echo "DMG: $DMG ($SIZE bytes)"
