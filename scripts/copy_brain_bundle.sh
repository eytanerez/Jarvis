#!/usr/bin/env bash
# Copy the Jarvis brain into Jarvis.app without carrying local development
# artifacts such as helper virtualenvs, tests, and bytecode caches.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${JARVIS_BRAIN_SOURCE:-$ROOT/brain}"
DEST="${1:-}"
RUNTIME_VENV="${JARVIS_BRAIN_RUNTIME_VENV:-$SOURCE/.venv}"
INCLUDE_RUNTIME_VENV="${JARVIS_INCLUDE_BRAIN_RUNTIME_VENV:-1}"

if [ -z "$DEST" ]; then
  echo "usage: scripts/copy_brain_bundle.sh <destination>" >&2
  exit 2
fi

if [ ! -d "$SOURCE" ]; then
  echo "warning: Jarvis brain source not found at $SOURCE; skipping copy" >&2
  exit 0
fi

copy_pruned_tree() {
  local source="$1"
  local dest="$2"
  shift 2
  local excludes=("$@")

  rm -rf "$dest"
  mkdir -p "$dest"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${excludes[@]}" "$source/" "$dest/"
    return
  fi

  (
    cd "$source"
    /usr/bin/tar "${excludes[@]}" -cf - .
  ) | (
    cd "$dest"
    /usr/bin/tar -xf -
  )
}

SOURCE_EXCLUDES=(
  "--exclude=.DS_Store"
  "--exclude=.coverage"
  "--exclude=.mypy_cache"
  "--exclude=.pytest_cache"
  "--exclude=.ruff_cache"
  "--exclude=.venv"
  "--exclude=.venv-*"
  "--exclude=__pycache__"
  "--exclude=*.pyc"
  "--exclude=*.pyo"
  "--exclude=build"
  "--exclude=dist"
  "--exclude=jarvis_brain.egg-info"
  "--exclude=tests"
)

VENV_EXCLUDES=(
  "--exclude=.DS_Store"
  "--exclude=.pytest_cache"
  "--exclude=__pycache__"
  "--exclude=*.pyc"
  "--exclude=*.pyo"
)

mkdir -p "$(dirname "$DEST")"
copy_pruned_tree "$SOURCE" "$DEST" "${SOURCE_EXCLUDES[@]}"
echo "Copied Jarvis brain source: $SOURCE -> $DEST"

if [ "$INCLUDE_RUNTIME_VENV" = "0" ]; then
  echo "Skipped bundled brain runtime venv (JARVIS_INCLUDE_BRAIN_RUNTIME_VENV=0)."
  exit 0
fi

if [ -x "$RUNTIME_VENV/bin/python" ] || [ -x "$RUNTIME_VENV/bin/python3" ]; then
  copy_pruned_tree "$RUNTIME_VENV" "$DEST/.venv" "${VENV_EXCLUDES[@]}"
  echo "Bundled brain runtime venv: $RUNTIME_VENV -> $DEST/.venv"
else
  echo "warning: no runtime venv found at $RUNTIME_VENV; bundled brain will need Python dependencies from the host" >&2
fi
