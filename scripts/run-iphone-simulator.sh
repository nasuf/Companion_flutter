#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR_DEVICE_ID="${SIMULATOR_DEVICE_ID:-D23C0EE4-3DAD-4CA5-B6E2-A0E574F2AD23}"
LOCAL_API_BASE_URL="${LOCAL_API_BASE_URL:-http://127.0.0.1:8000}"

# 选择 flavor：dev=com.bansheng.dev（默认），prod=com.bansheng.prod。
# ⚠️ 注意：iOS 模拟器不支持 StoreKit 沙盒内购（IapService.isAvailable() 返回
# false，价格回退营销价、无法真正下单）。这里加 prod 只是为了改包名/App Group
# 保持一致，真实内购测试必须走 run-iphone-device.sh 真机。
# 交互选择 flavor（与 build-testflight.sh 同款）：预设 FLAVOR 就沿用；无交互终端
# 默认 dev；否则问一次。
prompt_for_flavor() {
  if [[ -n "${FLAVOR:-}" ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    FLAVOR="dev"
    echo "No interactive terminal detected; defaulting to FLAVOR=dev"
    return
  fi
  echo "Which build do you want?"
  echo "  1) dev  — com.bansheng.dev   内部/日常调试"
  echo "  2) prod — com.bansheng.prod  仅改包名（模拟器测不了内购）"
  local choice=""
  if ! read -r -p "Select [1]: " choice; then
    echo >&2
    echo "No flavor selected; aborting." >&2
    exit 1
  fi
  case "${choice:-1}" in
    1 | dev) FLAVOR="dev" ;;
    2 | prod) FLAVOR="prod" ;;
    *)
      echo "Invalid selection: '$choice' (expected 1/dev or 2/prod)." >&2
      exit 1
      ;;
  esac
  echo
}
prompt_for_flavor

FLAVOR_OVERRIDE_FILE="ios/Flutter/FlavorOverride.xcconfig"

case "$FLAVOR" in
  dev)
    FLAVOR_APP_BUNDLE_ID="com.bansheng.dev"
    FLAVOR_APP_GROUP_ID="group.com.bansheng.dev"
    FLAVOR_APP_NAME_SUFFIX="Dev"
    ;;
  prod)
    FLAVOR_APP_BUNDLE_ID="com.bansheng.prod"
    FLAVOR_APP_GROUP_ID="group.com.bansheng.prod"
    FLAVOR_APP_NAME_SUFFIX=""
    ;;
  *)
    echo "Invalid FLAVOR: $FLAVOR (expected: dev or prod)" >&2
    exit 1
    ;;
esac

# 按所选 flavor 写 override、退出即删（与 build-testflight.sh 同机制）。
cat > "$FLAVOR_OVERRIDE_FILE" <<EOF
APP_BUNDLE_ID = $FLAVOR_APP_BUNDLE_ID
APP_GROUP_ID = $FLAVOR_APP_GROUP_ID
APP_NAME_SUFFIX = $FLAVOR_APP_NAME_SUFFIX
EOF
trap 'rm -f "$FLAVOR_OVERRIDE_FILE"' EXIT

echo "Flavor: $FLAVOR  bundle: $FLAVOR_APP_BUNDLE_ID (simulator)"

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
