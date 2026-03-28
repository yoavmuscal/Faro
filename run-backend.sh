#!/usr/bin/env bash
# Convenience wrapper from repo root: ./run-backend.sh
set -euo pipefail
exec "$(dirname "$0")/backend/run.sh"
