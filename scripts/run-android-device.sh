#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-}"
FLAVOR="${FLAVOR:-dev}"
DEV_API_BASE_URL="${DEV_API_BASE_URL:-https://banshengcomp.com/api}"
FLUTTER_RUN_MODE="${FLUTTER_RUN_MODE:-debug}"

case "$FLAVOR" in
  dev|prod) ;;
  *)
    echo "Invalid FLAVOR: $FLAVOR" >&2
    echo "Expected: dev or prod" >&2
    exit 1
    ;;
esac

case "$FLUTTER_RUN_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid FLUTTER_RUN_MODE: $FLUTTER_RUN_MODE" >&2
    echo "Expected: debug, profile, or release" >&2
    exit 1
    ;;
esac

if [[ -z "$ANDROID_DEVICE_ID" ]]; then
  ANDROID_DEVICE_ID="$(
    adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }'
  )"
fi

if [[ -z "$ANDROID_DEVICE_ID" ]]; then
  echo "No connected Android device found." >&2
  echo "Set ANDROID_DEVICE_ID=<device-id> and retry." >&2
  exit 1
fi

flutter pub get

flutter run \
  -d "$ANDROID_DEVICE_ID" \
  "--$FLUTTER_RUN_MODE" \
  --flavor "$FLAVOR" \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
  "$@"
