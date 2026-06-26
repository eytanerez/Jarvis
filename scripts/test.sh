#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift test
swift run JarvisTestHarness

if [ -x "$ROOT/brain/.venv/bin/python" ]; then
  PYTHONPATH="$ROOT/brain" "$ROOT/brain/.venv/bin/python" -m unittest discover -s "$ROOT/brain/tests"
elif command -v python3 >/dev/null 2>&1; then
  PYTHONPATH="$ROOT/brain" python3 -m unittest discover -s "$ROOT/brain/tests"
fi
