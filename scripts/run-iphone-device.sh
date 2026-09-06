#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PHYSICAL_DEVICE_ID="${PHYSICAL_DEVICE_ID:-00008130-0008350A3E11001C}"
DEV_API_BASE_URL="${DEV_API_BASE_URL:-https://banshengcomp.com/api}"
FLUTTER_RUN_MODE="${FLUTTER_RUN_MODE:-release}"

# 选择 flavor：dev=com.bansheng.dev（默认，行为不变），prod=com.bansheng.prod。
# prod 真机直装用于跑沙盒内购：真机 + 设置→开发者→Sandbox 账户 = 中国区
# storefront（价格显示人民币）。TestFlight 走真实 Apple ID storefront，美区账户
# 会显示美元——这也是为什么 IAP 要在这条 dev 直装链路上验，而不是 TestFlight。
# 签名走 Xcode 自动签名（CODE_SIGN_STYLE=Automatic, team F3FB94L862）：首次 prod
# 直装可能需要它联网生成 com.bansheng.prod 的开发描述文件（设备已注册即可）。
# 交互选择 flavor（与 build-testflight.sh 同款）：预设了 FLAVOR 就沿用（CI/重复
# 运行）；无交互终端默认 dev；否则问一次，避免静默出错包。
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
  echo "  2) prod — com.bansheng.prod  沙盒内购/正式包"
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

# 启动步骤要按包名找已装的 app，缺省跟随 flavor（不再写死 dev）。
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-$FLAVOR_APP_BUNDLE_ID}"

case "$FLUTTER_RUN_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid FLUTTER_RUN_MODE: $FLUTTER_RUN_MODE" >&2
    echo "Expected: debug, profile, or release" >&2
    exit 1
    ;;
esac

# 始终按所选 flavor 写 override、退出即删——防止上次崩溃残留的 override 让这次
# 静默出成另一个 flavor 的包（与 build-testflight.sh 同机制；文件已 gitignore）。
cat > "$FLAVOR_OVERRIDE_FILE" <<EOF
APP_BUNDLE_ID = $FLAVOR_APP_BUNDLE_ID
APP_GROUP_ID = $FLAVOR_APP_GROUP_ID
APP_NAME_SUFFIX = $FLAVOR_APP_NAME_SUFFIX
EOF
trap 'rm -f "$FLAVOR_OVERRIDE_FILE"' EXIT

echo "Flavor: $FLAVOR  bundle: $FLAVOR_APP_BUNDLE_ID  mode: $FLUTTER_RUN_MODE"

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
