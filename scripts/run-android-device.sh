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

# ANDROID_DEVICE_ID skips the prompt. Otherwise list every adb device in the
# "device" state and, on a terminal, ask which one receives this build.
# Unauthorized/offline devices are shown but cannot be selected.
select_android_device() {
  if [[ -n "${ANDROID_DEVICE_ID:-}" ]]; then
    return
  fi

  local listing ids=() models=() skipped=() kind id extra
  listing="$(adb devices -l | awk '
    NR == 1 || NF < 2 { next }
    $2 == "device" {
      model = $1
      for (i = 3; i <= NF; i++) if ($i ~ /^model:/) model = substr($i, 7)
      printf "ready\t%s\t%s\n", $1, model
      next
    }
    { printf "skip\t%s\t%s\n", $1, $2 }
  ')"

  while IFS=$'\t' read -r kind id extra; do
    [[ -n "${kind:-}" ]] || continue
    if [[ "$kind" == "skip" ]]; then
      skipped+=("$id  $extra")
    elif [[ "$kind" == "ready" ]]; then
      ids+=("$id")
      models+=("$extra")
    fi
  done <<< "$listing"

  if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "Not ready:"
    local item
    for item in "${skipped[@]}"; do
      echo "  $item"
    done
  fi

  if [[ ${#ids[@]} -eq 0 ]]; then
    echo "No connected Android device is ready." >&2
    echo "Authorize a device, or set ANDROID_DEVICE_ID=<device-id> and retry." >&2
    exit 1
  fi

  if [[ ! -t 0 ]]; then
    if [[ ${#ids[@]} -eq 1 ]]; then
      ANDROID_DEVICE_ID="${ids[0]}"
      ANDROID_DEVICE_LABEL="${models[0]} ($ANDROID_DEVICE_ID)"
      echo "No interactive terminal detected; using $ANDROID_DEVICE_LABEL"
      return
    fi
    echo "Multiple Android devices are connected. Set ANDROID_DEVICE_ID and retry." >&2
    local i
    for i in "${!ids[@]}"; do
      echo "  ${ids[$i]}  ${models[$i]}" >&2
    done
    exit 1
  fi

  echo "Which Android device do you want?"
  local i
  for i in "${!ids[@]}"; do
    printf '  %d) %s  %s\n' "$((i + 1))" "${models[$i]}" "${ids[$i]}"
  done
  local choice=""
  if ! read -r -p "Select [1]: " choice; then
    echo >&2
    echo "No device selected; aborting." >&2
    exit 1
  fi
  choice="${choice:-1}"
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ids[@]} )); then
    echo "Invalid selection: '$choice' (expected 1-${#ids[@]})." >&2
    exit 1
  fi
  ANDROID_DEVICE_ID="${ids[$((choice - 1))]}"
  ANDROID_DEVICE_LABEL="${models[$((choice - 1))]} ($ANDROID_DEVICE_ID)"
  echo
}

ANDROID_DEVICE_LABEL=""
select_android_device

echo "Running $FLAVOR (com.bansheng.$FLAVOR) $FLUTTER_RUN_MODE on ${ANDROID_DEVICE_LABEL:-$ANDROID_DEVICE_ID}"

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
