#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

IPAD_SIMULATOR_DEVICE_ID="${IPAD_SIMULATOR_DEVICE_ID:-7F68F777-D2F2-4FE5-90E8-4A5DA16AE944}"
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
  -d "$IPAD_SIMULATOR_DEVICE_ID" \
  --no-pub \
  --dart-define=API_BASE_URL="$LOCAL_API_BASE_URL" \
  "$@"
