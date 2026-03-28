#!/usr/bin/env bash
# Start the Faro API (FastAPI + uvicorn). Run from repo root: ./backend/run.sh
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -d .venv ]]; then
  echo "No backend/.venv found. Create it with:" >&2
  echo "  cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
  exit 1
fi

# shellcheck source=/dev/null
source .venv/bin/activate
exec uvicorn main:app --host 127.0.0.1 --port 8000
