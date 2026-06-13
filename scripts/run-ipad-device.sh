#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

IPAD_DEVICE_ID="${IPAD_DEVICE_ID:-}"
DEV_API_BASE_URL="${DEV_API_BASE_URL:-https://banshengcomp.com/api}"
FLUTTER_RUN_MODE="${FLUTTER_RUN_MODE:-release}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.bansheng.dev}"

case "$FLUTTER_RUN_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid FLUTTER_RUN_MODE: $FLUTTER_RUN_MODE" >&2
    echo "Expected: debug, profile, or release" >&2
    exit 1
    ;;
esac

if [[ -z "$IPAD_DEVICE_ID" ]]; then
  IPAD_DEVICE_ID="$(
    xcrun devicectl list devices 2>/dev/null \
      | awk '$0 ~ /iPad/ && $0 ~ /connected/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-Fa-f-]{36}$/) { print $i; exit } }'
  )"
fi

if [[ -z "$IPAD_DEVICE_ID" ]]; then
  echo "No connected iPad device found." >&2
  echo "Set IPAD_DEVICE_ID=<device-id> and retry." >&2
  exit 1
fi

if [[ "$FLUTTER_RUN_MODE" != "debug" ]]; then
  flutter build ios \
    "--$FLUTTER_RUN_MODE" \
    --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
    "$@"

  xcrun devicectl device install app \
    --device "$IPAD_DEVICE_ID" \
    build/ios/iphoneos/Runner.app

  xcrun devicectl device process launch \
    --device "$IPAD_DEVICE_ID" \
    "$IOS_BUNDLE_ID"

  exit 0
fi

flutter run \
  -d "$IPAD_DEVICE_ID" \
  --device-connection attached \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
  "$@"
