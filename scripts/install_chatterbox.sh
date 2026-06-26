#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-}"
VENV="$ROOT/brain/.venv-chatterbox"

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
"$VENV/bin/python" -m pip install "chatterbox-tts==0.1.7"
"$VENV/bin/python" "$ROOT/brain/app/chatterbox_worker.py" --status
