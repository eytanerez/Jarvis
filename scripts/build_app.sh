#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-Debug}"
case "$CONFIG" in
  debug) CONFIG="Debug" ;;
  release) CONFIG="Release" ;;
esac

CONFIGURATION="$CONFIG" "$ROOT/script/build_and_run.sh" build
