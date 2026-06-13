#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

require_clean_git_worktree() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  local dirty_status
  dirty_status="$(git status --porcelain)"
  if [[ -z "$dirty_status" ]]; then
    echo "Git state: clean ($(git rev-parse --abbrev-ref HEAD) $(git rev-parse --short HEAD))"
    return
  fi

  if [[ "${ALLOW_DIRTY:-0}" == "1" ]]; then
    echo "WARNING: ALLOW_DIRTY=1, building with uncommitted changes:"
    echo "$dirty_status"
    echo
    return
  fi

  echo "Refusing to build Android APK from a dirty working tree." >&2
  echo "Commit or stash your changes first, or rerun with ALLOW_DIRTY=1 to build the current local state." >&2
  echo >&2
  echo "Dirty files:" >&2
  echo "$dirty_status" >&2
  exit 1
}

require_clean_git_worktree

FLAVOR="${FLAVOR:-dev}"
case "$FLAVOR" in
  dev|prod) ;;
  *)
    echo "Invalid FLAVOR: $FLAVOR" >&2
    echo "Expected: dev or prod" >&2
    exit 1
    ;;
esac

API_BASE_URL="${API_BASE_URL:-https://banshengcomp.com/api}"
INSTALL_ANDROID="${INSTALL_ANDROID:-1}"

version_line="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$' pubspec.yaml || true)"
if [[ -z "$version_line" ]]; then
  echo "Could not find a valid pubspec.yaml version line like: version: 0.1.0+1" >&2
  exit 1
fi

current="${version_line#version: }"
current="${current//[[:space:]]/}"
current_build_name="${current%%+*}"
current_build_number="${current##*+}"

IFS='.' read -r major minor patch <<< "$current_build_name"
suggested_build_name="$major.$minor.$((patch + 1))"
suggested_build_number="$((current_build_number + 1))"

echo "Android flavor:             $FLAVOR"
echo "Application ID:             com.bansheng.$FLAVOR"
echo "Current app version:        $current_build_name"
echo "Current version code:       $current_build_number"
echo "Suggested next app version: $suggested_build_name"
echo "Suggested next version code:$suggested_build_number"
echo "API_BASE_URL:               $API_BASE_URL"
echo

if [[ -n "${BUILD_VERSION:-}" && "$BUILD_VERSION" == *+* ]]; then
  build_name="${BUILD_VERSION%%+*}"
  build_number="${BUILD_VERSION##*+}"
  echo "Using BUILD_VERSION=$BUILD_VERSION"
elif [[ -n "${BUILD_VERSION:-}" ]]; then
  build_name="$BUILD_VERSION"
  build_number="${BUILD_NUMBER:-$current_build_number}"
  echo "Using BUILD_VERSION=$build_name and BUILD_NUMBER=$build_number"
elif [[ -n "${BUILD_NAME:-}" || -n "${BUILD_NUMBER:-}" ]]; then
  build_name="${BUILD_NAME:-$current_build_name}"
  build_number="${BUILD_NUMBER:-$current_build_number}"
  echo "Using BUILD_NAME=$build_name and BUILD_NUMBER=$build_number"
elif [[ -t 0 ]]; then
  read -r -p "App version for this Android build [$current_build_name] (type $suggested_build_name for next): " build_name
  build_name="${build_name:-$current_build_name}"

  if [[ "$build_name" == "$current_build_name" ]]; then
    default_build_number="$current_build_number"
  else
    default_build_number="1"
  fi

  read -r -p "Android versionCode [$default_build_number]: " build_number
  build_number="${build_number:-$default_build_number}"
else
  build_name="$current_build_name"
  build_number="$current_build_number"
  echo "No interactive terminal detected; using current app version $build_name code $build_number"
fi

if [[ ! "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid app version: $build_name" >&2
  echo "Expected format: 0.1.0" >&2
  exit 1
fi

if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  echo "Invalid Android versionCode: $build_number" >&2
  echo "Expected format: 1" >&2
  exit 1
fi

selected_version="$build_name+$build_number"

echo
echo "Building Android APK flavor $FLAVOR, app version $build_name, versionCode $build_number"

build_started_marker="$(mktemp -t build-android-apk-start.XXXXXX)"
trap 'rm -f "$build_started_marker"' EXIT

flutter pub get

flutter build apk --release \
  --flavor "$FLAVOR" \
  --build-name="$build_name" \
  --build-number="$build_number" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "$@"

expected_apk="$ROOT_DIR/build/app/outputs/flutter-apk/app-$FLAVOR-release.apk"
if [[ -f "$expected_apk" ]]; then
  apk_path="$expected_apk"
else
  shopt -s nullglob
  apk_files=("$ROOT_DIR"/build/app/outputs/flutter-apk/*.apk)
  shopt -u nullglob
  if [[ "${#apk_files[@]}" -eq 0 ]]; then
    echo "Could not find an APK under $ROOT_DIR/build/app/outputs/flutter-apk" >&2
    exit 1
  fi
  apk_path="${apk_files[0]}"
  for candidate in "${apk_files[@]}"; do
    if [[ "$candidate" -nt "$apk_path" ]]; then
      apk_path="$candidate"
    fi
  done
fi

if [[ ! "$apk_path" -nt "$build_started_marker" ]]; then
  echo "No fresh APK was produced by this build." >&2
  echo "Newest APK found: $apk_path" >&2
  exit 1
fi

if [[ "$selected_version" != "$current" ]]; then
  CURRENT="$current" NEXT="$selected_version" perl -0pi -e \
    's/^version:\s*\Q$ENV{CURRENT}\E\s*$/version: $ENV{NEXT}/m' pubspec.yaml

  if ! grep -q "version: $selected_version" pubspec.yaml; then
    echo "Could not update pubspec.yaml from $current to $selected_version" >&2
    exit 1
  fi
fi

echo "APK output: $apk_path"
echo "Built Android app version: $build_name"
echo "Built Android versionCode: $build_number"
echo "Flutter pubspec app+build version: $selected_version"

if [[ "$INSTALL_ANDROID" != "0" ]]; then
  device_id="${ANDROID_DEVICE_ID:-}"
  if [[ -z "$device_id" ]]; then
    device_id="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  fi

  if [[ -z "$device_id" ]]; then
    echo "No connected Android device found. APK was built but not installed." >&2
    exit 0
  fi

  echo "Installing APK on Android device: $device_id"
  adb -s "$device_id" install -r "$apk_path"
fi
