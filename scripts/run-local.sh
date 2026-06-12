#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR_DEVICE_ID="${SIMULATOR_DEVICE_ID:-D23C0EE4-3DAD-4CA5-B6E2-A0E574F2AD23}"
LOCAL_API_BASE_URL="${LOCAL_API_BASE_URL:-http://127.0.0.1:8000}"

flutter pub get

if [[ "$(uname -s)" == "Darwin" && -d ios ]]; then
  (
    cd ios
    pod install
  )
  xattr -dr com.apple.provenance ios/Pods 2>/dev/null || true
  xattr -dr com.apple.quarantine ios/Pods 2>/dev/null || true
fi

flutter run \
  -d "$SIMULATOR_DEVICE_ID" \
  --no-pub \
  --dart-define=API_BASE_URL="$LOCAL_API_BASE_URL" \
  "$@"
