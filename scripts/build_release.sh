#!/usr/bin/env bash
# Build a release Jarvis.app from the Xcode project.
#
# 1. (optionally) increment BUILD_NUMBER
# 2. generate BuildInfo.swift + brain build constants from the version SSOT
# 3. archive + export the signed app  (falls back to an unsigned dev build when
#    no Developer ID identity is available)
#
# Output: build/export/Jarvis.app  (path printed at the end)
#
# Env / flags:
#   --no-increment        do not bump BUILD_NUMBER
#   --version X.Y.Z       override VERSION for this build
#   --channel dev|beta|stable
#   DEVELOPER_ID_APP      "Developer ID Application: Name (TEAMID)" for signing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INCREMENT=1
OVERRIDE_VERSION=""
CHANNEL="$(tr -d '[:space:]' < "$ROOT/UPDATE_CHANNEL" 2>/dev/null || echo dev)"

while [ $# -gt 0 ]; do
  case "$1" in
    --no-increment) INCREMENT=0 ;;
    --version) OVERRIDE_VERSION="$2"; shift ;;
    --channel) CHANNEL="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

PROJECT="$ROOT/Atoll/DynamicIsland.xcodeproj"
SCHEME="DynamicIsland"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/Jarvis.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Jarvis.app"

[ -n "$OVERRIDE_VERSION" ] && printf '%s\n' "$OVERRIDE_VERSION" > "$ROOT/VERSION"
printf '%s\n' "$CHANNEL" > "$ROOT/UPDATE_CHANNEL"

if [ "$INCREMENT" = "1" ]; then
  CURRENT="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER" 2>/dev/null || echo 0)"
  NEXT=$(( CURRENT + 1 ))
  printf '%s\n' "$NEXT" > "$ROOT/BUILD_NUMBER"
  echo "==> bumped build number: $CURRENT -> $NEXT"
fi

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"

echo "==> generating build info ($VERSION+$BUILD_NUMBER, channel=$CHANNEL)"
"$ROOT/scripts/generate_build_info.sh"

rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

COMMON_SETTINGS=(
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  echo "==> archiving signed release with: $DEVELOPER_ID_APP"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
    "${COMMON_SETTINGS[@]}" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APP" \
    archive

  EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"
  cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_PLIST" -exportPath "$EXPORT_DIR"
else
  echo "==> WARNING: DEVELOPER_ID_APP not set — building UNSIGNED dev app."
  echo "    This build must not be distributed through stable/beta channels."
  mkdir -p "$EXPORT_DIR"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR/dd" \
    "${COMMON_SETTINGS[@]}" \
    CODE_SIGNING_ALLOWED=NO build
  SRC="$BUILD_DIR/dd/Build/Products/Release/Jarvis.app"
  rm -rf "$APP"
  cp -R "$SRC" "$APP"
fi

echo ""
echo "Built: $APP"
echo "Version: $VERSION ($BUILD_NUMBER), channel: $CHANNEL"
