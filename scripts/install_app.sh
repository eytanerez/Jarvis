#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Jarvis"
CONFIG="${1:-Debug}"
case "$CONFIG" in
  debug) CONFIG="Debug" ;;
  release) CONFIG="Release" ;;
esac

"$ROOT/scripts/build_app.sh" "$CONFIG"

SRC="$ROOT/.build/xcode/Build/Products/$CONFIG/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

echo "==> Stopping any running instance..."
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 0.5

echo "==> Installing to ${DEST} ..."
if ! ( rm -rf "${DEST}" && cp -R "${SRC}" "${DEST}" ) 2>/dev/null; then
  echo "    /Applications not writable; installing to ~/Applications instead."
  mkdir -p "${HOME}/Applications"
  DEST="${HOME}/Applications/${APP_NAME}.app"
  rm -rf "${DEST}"
  cp -R "${SRC}" "${DEST}"
fi

codesign --force --deep --sign - "${DEST}" >/dev/null 2>&1 || true

echo "==> Launching..."
open "${DEST}"

cat <<EOF

Installed: ${DEST}
- Jarvis runs in the background; look for the notch glyph in your menu bar.
- Press Option-Space to talk.
- It registers to open at login automatically (toggle it in the menu bar item).
EOF
