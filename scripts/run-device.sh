#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PHYSICAL_DEVICE_ID="${PHYSICAL_DEVICE_ID:-00008130-0008350A3E11001C}"
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

if [[ "$FLUTTER_RUN_MODE" != "debug" ]]; then
  flutter build ios \
    "--$FLUTTER_RUN_MODE" \
    --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
    "$@"

  xcrun devicectl device install app \
    --device "$PHYSICAL_DEVICE_ID" \
    build/ios/iphoneos/Runner.app

  xcrun devicectl device process launch \
    --device "$PHYSICAL_DEVICE_ID" \
    "$IOS_BUNDLE_ID"

  exit 0
fi

flutter run \
  -d "$PHYSICAL_DEVICE_ID" \
  --device-connection attached \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
  "$@"
