#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/fresh-build.sh"

cd "$(dirname "$0")/.."

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-}"
# WeChat's Android app accepts one package name. Use prod (com.bansheng.prod)
# and default to release so the configured release certificate is used.
FLAVOR="${FLAVOR:-prod}"
DEV_API_BASE_URL="${DEV_API_BASE_URL:-https://banshengcomp.com/api}"
# Opt into hot reload with FLUTTER_RUN_MODE=debug (uses the debug certificate).
FLUTTER_RUN_MODE="${FLUTTER_RUN_MODE:-release}"

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

echo "Running $FLAVOR (com.bansheng.$FLAVOR) $FLUTTER_RUN_MODE on $ANDROID_DEVICE_ID"

fresh_build_prepare
source_fingerprint="$(fresh_build_fingerprint)"
fresh_build_run_options "$@"

flutter build apk "--$FLUTTER_RUN_MODE" --flavor "$FLAVOR" \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" "${build_extra[@]}"
apk_path="$PWD/build/app/outputs/flutter-apk/app-$FLAVOR-$FLUTTER_RUN_MODE.apk"
if [[ "$FLUTTER_RUN_MODE" != "debug" ]]; then
  variant="$FLAVOR$(tr '[:lower:]' '[:upper:]' <<< "${FLUTTER_RUN_MODE:0:1}")${FLUTTER_RUN_MODE:1}"
  python3 scripts/verify_android_aot.py "$apk_path" \
    "build/app/intermediates/flutter/$variant/jniLibs"
fi
fresh_build_seal "$apk_path" "$source_fingerprint"
fresh_build_verify "$apk_path"
python3 scripts/flutter_build_guard.py install-android "$apk_path" "$ANDROID_DEVICE_ID" "com.bansheng.$FLAVOR"

# Run exactly the APK that passed verification, without a second native build.
flutter run \
  -d "$ANDROID_DEVICE_ID" \
  "--$FLUTTER_RUN_MODE" \
  --flavor "$FLAVOR" \
  --use-application-binary="$apk_path" \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
  "${run_extra[@]}"
