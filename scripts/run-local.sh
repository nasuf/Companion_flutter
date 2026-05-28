#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  "$@"
