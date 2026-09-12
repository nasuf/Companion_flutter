#!/usr/bin/env bash
# Release APK counterpart of build-testflight.sh.
# Version comes from the same pubspec.yaml line both stores ship
# (`0.5.0+3` → versionName + versionCode). Output is copied to
#   build/android/bansheng-dev-0.5.0+3.apk
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_STARTED_DIRTY=0

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
  echo "  1) dev  — com.bansheng.dev   internal sideload"
  echo "  2) prod — com.bansheng.prod  production package"
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

resolve_flavor() {
  case "$FLAVOR" in
    dev)
      APPLICATION_ID="com.bansheng.dev"
      ;;
    prod)
      APPLICATION_ID="com.bansheng.prod"
      ;;
    *)
      echo "Unknown FLAVOR: '$FLAVOR' (expected 'dev' or 'prod')." >&2
      exit 1
      ;;
  esac
}

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
    BUILD_STARTED_DIRTY=1
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

commit_version_change() {
  local version="$1"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  if [[ "$BUILD_STARTED_DIRTY" == "1" ]]; then
    echo "Skipping automatic version commit because ALLOW_DIRTY=1 was used."
    return
  fi

  if git diff --quiet -- pubspec.yaml; then
    return
  fi

  git add pubspec.yaml
  git commit -m "Bump mobile build version to $version"
}

find_aapt() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "$sdk" && -d "$HOME/Library/Android/sdk" ]]; then
    sdk="$HOME/Library/Android/sdk"
  fi
  if [[ -z "$sdk" ]]; then
    return
  fi
  ls -1d "$sdk"/build-tools/*/aapt 2>/dev/null | tail -1 || true
}

verify_apk_identity() {
  local apk="$1"
  local aapt
  aapt="$(find_aapt)"
  if [[ -z "$aapt" || ! -x "$aapt" ]]; then
    echo "Skipping APK identity check (aapt not found)."
    return
  fi

  local badging actual_id actual_name actual_code
  badging="$("$aapt" dump badging "$apk")"
  actual_id="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging" | head -1)"
  actual_code="$(sed -n "s/^package:.*versionCode='\([^']*\)'.*/\1/p" <<<"$badging" | head -1)"
  actual_name="$(sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p" <<<"$badging" | head -1)"

  if [[ "$actual_id" != "$APPLICATION_ID" ]]; then
    echo "Built APK has applicationId '$actual_id' but flavor '$FLAVOR' expects '$APPLICATION_ID'." >&2
    exit 1
  fi
  echo "Verified applicationId: $actual_id"

  if [[ "$actual_name" != "$build_name" ]]; then
    echo "Built APK versionName is '$actual_name' but expected '$build_name'." >&2
    exit 1
  fi
  echo "Verified versionName:   $actual_name"

  if [[ "$actual_code" != "$build_number" ]]; then
    echo "Built APK versionCode is '$actual_code' but expected '$build_number'." >&2
    exit 1
  fi
  echo "Verified versionCode:   $actual_code"
}

# Worktree gate first: no point asking which flavor to build only to reject the
# run over uncommitted changes.
require_clean_git_worktree
prompt_for_flavor
resolve_flavor

# Release is the sideload default. BUILD_MODE=debug remains an escape hatch
# for a larger, slower package that matches `flutter run`.
BUILD_MODE="${BUILD_MODE:-release}"
case "$BUILD_MODE" in
  debug | release) ;;
  *)
    echo "Unknown BUILD_MODE: '$BUILD_MODE' (expected 'debug' or 'release')." >&2
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

echo "Flavor:                     $FLAVOR"
echo "Application ID:             $APPLICATION_ID"
echo "Build mode:                 $BUILD_MODE"
if [[ "$FLAVOR" == "dev" ]]; then
  echo "Current app version:        $current_build_name"
  echo "Current build number:       $current_build_number"
  echo "Suggested next app version: $suggested_build_name"
  echo "Suggested next build no.:   $suggested_build_number"
else
  # Only dev maintains the version line; prod ships whatever dev last built.
  echo "Version (pinned to dev):    $current_build_name (build $current_build_number)"
fi
echo "API_BASE_URL:               $API_BASE_URL"
echo

if [[ "$FLAVOR" != "dev" ]]; then
  if [[ -n "${BUILD_VERSION:-}" || -n "${BUILD_NAME:-}" || -n "${BUILD_NUMBER:-}" ]]; then
    echo "BUILD_VERSION / BUILD_NAME / BUILD_NUMBER are not accepted for FLAVOR=$FLAVOR." >&2
    echo "Prod ships dev's current version ($current). Run a dev build first to move it." >&2
    exit 1
  fi
  build_name="$current_build_name"
  build_number="$current_build_number"
elif [[ -n "${BUILD_VERSION:-}" && "$BUILD_VERSION" == *+* ]]; then
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

  read -r -p "Build number (shared with TestFlight) [$default_build_number] (bump if already shipped): " build_number
  build_number="${build_number:-$default_build_number}"
else
  build_name="$current_build_name"
  build_number="$current_build_number"
  echo "No interactive terminal detected; using current app version $build_name build $build_number"
fi

if [[ ! "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid app version: $build_name" >&2
  echo "Expected format: 0.1.0" >&2
  exit 1
fi

if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  echo "Invalid build number: $build_number" >&2
  echo "Expected format: 1" >&2
  exit 1
fi

selected_version="$build_name+$build_number"
if [[ "$BUILD_MODE" == "release" ]]; then
  output_name="bansheng-${FLAVOR}-${build_name}+${build_number}.apk"
else
  output_name="bansheng-${FLAVOR}-${build_name}+${build_number}-${BUILD_MODE}.apk"
fi

echo
echo "Building Android APK flavor $FLAVOR, $BUILD_MODE, app version $build_name, build $build_number"

build_started_marker="$(mktemp -t build-android-apk-start.XXXXXX)"
trap 'rm -f "$build_started_marker"' EXIT

if [[ "${CLEAN:-0}" == "1" ]]; then
  flutter clean
fi
flutter pub get

flutter build apk "--$BUILD_MODE" \
  --flavor "$FLAVOR" \
  --build-name="$build_name" \
  --build-number="$build_number" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "$@"

expected_apk="$ROOT_DIR/build/app/outputs/flutter-apk/app-$FLAVOR-$BUILD_MODE.apk"
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

verify_apk_identity "$apk_path"

output_dir="$ROOT_DIR/build/android"
mkdir -p "$output_dir"
output_apk="$output_dir/$output_name"
cp "$apk_path" "$output_apk"

# Only dev maintains the version line. Prod is pinned to what it read, so it has
# nothing to write back — same contract as build-testflight.sh.
if [[ "$FLAVOR" == "dev" ]]; then
  if [[ "$selected_version" != "$current" ]]; then
    CURRENT="$current" NEXT="$selected_version" perl -0pi -e \
      's/^version:\s*\Q$ENV{CURRENT}\E\s*$/version: $ENV{NEXT}/m' pubspec.yaml

    if ! grep -q "version: $selected_version" pubspec.yaml; then
      echo "Could not update pubspec.yaml from $current to $selected_version" >&2
      exit 1
    fi

    commit_version_change "$selected_version"
  fi
fi

echo "APK output: $output_apk"
echo "Built flavor: $FLAVOR"
echo "Built mode: $BUILD_MODE"
echo "Built Android app version: $build_name"
echo "Built Android build number: $build_number"
if [[ "$FLAVOR" == "dev" ]]; then
  echo "Flutter pubspec app+build version: $selected_version"
else
  echo "Flutter pubspec app+build version: $current (unchanged)"
fi

if [[ "$(uname -s)" == "Darwin" && "${OPEN_OUTPUT:-1}" != "0" ]]; then
  echo "Revealing APK in Finder: $output_apk"
  open -R "$output_apk"
fi

if [[ "$INSTALL_ANDROID" != "0" ]]; then
  device_id="${ANDROID_DEVICE_ID:-}"
  if [[ -z "$device_id" ]]; then
    device_id="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  fi

  if [[ -z "$device_id" ]]; then
    echo "No connected Android device found. APK was built but not installed."
  else
    echo "Installing APK on Android device: $device_id"
    adb -s "$device_id" install -r "$output_apk"
  fi
fi
