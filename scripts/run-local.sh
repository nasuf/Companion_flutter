#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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
  --no-pub \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  "$@"
