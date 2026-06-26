#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-}"
VENV="$ROOT/brain/.venv-f5-tts"

if [ -z "$PYTHON" ]; then
  if [ -x /opt/homebrew/bin/python3.12 ]; then
    PYTHON=/opt/homebrew/bin/python3.12
  else
    PYTHON=python3
  fi
fi

if [ ! -x "$VENV/bin/python" ]; then
  "$PYTHON" -m venv "$VENV"
fi

"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install "f5-tts==1.1.20"
"$VENV/bin/python" "$ROOT/brain/app/f5_tts_worker.py" --status
