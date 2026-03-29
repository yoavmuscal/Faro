#!/usr/bin/env bash
# Start the Faro API (FastAPI + uvicorn). Run from repo root: ./backend/run.sh
set -euo pipefail
cd "$(dirname "$0")"

# Prefer .venv; fall back to .uenv (some clones use that name).
if [[ -d .venv ]]; then
  VENV_DIR=".venv"
elif [[ -d .uenv ]]; then
  VENV_DIR=".uenv"
else
  echo "No venv in backend/ — creating .venv and installing requirements (first run only)…" >&2
  python3 -m venv .venv
  .venv/bin/pip install -U pip >/dev/null
  .venv/bin/pip install -r requirements.txt
  VENV_DIR=".venv"
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"
exec uvicorn main:app --host 127.0.0.1 --port 8000
