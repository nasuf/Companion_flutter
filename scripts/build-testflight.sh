#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_STARTED_DIRTY=0

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

  echo "Refusing to build TestFlight IPA from a dirty working tree." >&2
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

  local files_to_commit=()
  if ! git diff --quiet -- pubspec.yaml; then
    files_to_commit+=(pubspec.yaml)
  fi
  if [[ -f ios/Podfile.lock ]] && ! git diff --quiet -- ios/Podfile.lock; then
    files_to_commit+=(ios/Podfile.lock)
  fi

  if [[ "${#files_to_commit[@]}" -eq 0 ]]; then
    return
  fi

  git add "${files_to_commit[@]}"
  git commit -m "Bump mobile build version to $version"
}

profile_has_app_group() {
  local decoded_plist="$1"
  local app_group_id="$2"

  /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.security.application-groups" "$decoded_plist" 2>/dev/null |
    grep -q "$app_group_id"
}

install_ios_profile() {
  local profile_path="$1"
  local bundle_id="$2"
  local app_group_id="$3"
  local name_var="$4"

  local decoded_plist
  decoded_plist="$(mktemp -t bansheng-profile.XXXXXX.plist)"
  security cms -D -i "$profile_path" > "$decoded_plist"

  local profile_uuid
  local profile_name
  local app_identifier
  profile_uuid="$(plutil -extract UUID raw -o - "$decoded_plist")"
  profile_name="$(plutil -extract Name raw -o - "$decoded_plist")"
  app_identifier="$(plutil -extract Entitlements.application-identifier raw -o - "$decoded_plist")"

  if [[ "$app_identifier" != "${IOS_TEAM_ID:-F3FB94L862}.$bundle_id" ]]; then
    echo "Provisioning profile '$profile_name' is for '$app_identifier', not '${IOS_TEAM_ID:-F3FB94L862}.$bundle_id'." >&2
    rm -f "$decoded_plist"
    exit 1
  fi

  if [[ -n "$app_group_id" ]] && ! profile_has_app_group "$decoded_plist" "$app_group_id"; then
    echo "Provisioning profile '$profile_name' does not include App Group '$app_group_id'." >&2
    echo "Regenerate this App Store profile in Apple Developer after enabling App Groups for bundle id '$bundle_id'." >&2
    rm -f "$decoded_plist"
    exit 1
  fi

  printf -v "$name_var" "%s" "$profile_name"

  local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$profile_dir"
  cp "$profile_path" "$profile_dir/$profile_uuid.mobileprovision"
  xattr -d com.apple.quarantine "$profile_dir/$profile_uuid.mobileprovision" 2>/dev/null || true
  xattr -d com.apple.provenance "$profile_dir/$profile_uuid.mobileprovision" 2>/dev/null || true

  rm -f "$decoded_plist"
  echo "Installed provisioning profile: $profile_name ($profile_uuid)"
}

install_ios_distribution_profiles() {
  IOS_APP_BUNDLE_ID="${IOS_BUNDLE_ID:-com.bansheng.dev}"
  IOS_SHARE_EXTENSION_BUNDLE_ID="${IOS_SHARE_EXTENSION_BUNDLE_ID:-com.bansheng.dev.ShareExtension}"
  IOS_APP_GROUP_ID="${IOS_APP_GROUP_ID:-group.com.bansheng.dev}"

  local app_profile_path="${IOS_APP_PROFILE_PATH:-${IOS_PROVISIONING_PROFILE_PATH:-$ROOT_DIR/../Bansheng_Dev_App_Store.mobileprovision}}"
  local extension_profile_path="${IOS_SHARE_EXTENSION_PROFILE_PATH:-$ROOT_DIR/../Bansheng_Dev_Share_Extension_App_Store.mobileprovision}"

  if [[ ! -f "$app_profile_path" ]]; then
    echo "No local app provisioning profile found at: $app_profile_path"
    echo "Set IOS_APP_PROFILE_PATH=/path/to/profile.mobileprovision if Xcode automatic signing cannot export."
    return
  fi

  install_ios_profile "$app_profile_path" "$IOS_APP_BUNDLE_ID" "$IOS_APP_GROUP_ID" IOS_APP_PROFILE_NAME

  if [[ -d "$ROOT_DIR/ios/Share Extension" ]]; then
    if [[ ! -f "$extension_profile_path" ]]; then
      echo "No local Share Extension provisioning profile found at: $extension_profile_path" >&2
      echo "Create/download an App Store profile for '$IOS_SHARE_EXTENSION_BUNDLE_ID' with App Group '$IOS_APP_GROUP_ID' enabled." >&2
      echo "Then save it there, or set IOS_SHARE_EXTENSION_PROFILE_PATH=/path/to/profile.mobileprovision." >&2
      exit 1
    fi

    install_ios_profile "$extension_profile_path" "$IOS_SHARE_EXTENSION_BUNDLE_ID" "$IOS_APP_GROUP_ID" IOS_SHARE_EXTENSION_PROFILE_NAME
  fi
}

create_ios_export_options_plist() {
  local export_options_path="$1"

  if [[ -z "${IOS_APP_PROFILE_NAME:-}" ]]; then
    return 1
  fi

  local extension_profile_entry=""
  if [[ -n "${IOS_SHARE_EXTENSION_PROFILE_NAME:-}" ]]; then
    extension_profile_entry="    <key>${IOS_SHARE_EXTENSION_BUNDLE_ID:-com.bansheng.dev.ShareExtension}</key>
    <string>$IOS_SHARE_EXTENSION_PROFILE_NAME</string>"
  fi

  cat > "$export_options_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>${IOS_TEAM_ID:-F3FB94L862}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
$extension_profile_entry
    <key>${IOS_APP_BUNDLE_ID:-com.bansheng.dev}</key>
    <string>$IOS_APP_PROFILE_NAME</string>
  </dict>
  <key>destination</key>
  <string>export</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
}

require_clean_git_worktree

API_BASE_URL="${API_BASE_URL:-https://banshengcomp.com/api}"

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

echo "Current app version:        $current_build_name"
echo "Current build number:       $current_build_number"
echo "Suggested next app version: $suggested_build_name"
echo "Suggested next build no.:   $suggested_build_number"
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
  read -r -p "App version for this TestFlight build [$current_build_name] (type $suggested_build_name for next): " build_name
  build_name="${build_name:-$current_build_name}"

  if [[ "$build_name" == "$current_build_name" ]]; then
    default_build_number="$current_build_number"
  else
    default_build_number="1"
  fi

  read -r -p "Build number for App Store Connect [$default_build_number]: " build_number
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

echo
echo "Building TestFlight IPA app version $build_name, build $build_number"

build_started_marker="$(mktemp -t build-testflight-start.XXXXXX)"
trap 'rm -f "$build_started_marker"' EXIT

install_ios_distribution_profiles

flutter clean
flutter pub get

if [[ "$(uname -s)" == "Darwin" && -d ios ]]; then
  (
    cd ios
    pod install
  )
fi

export_options_plist="$(mktemp -t bansheng-export-options.XXXXXX.plist)"
if create_ios_export_options_plist "$export_options_plist"; then
  export_options_args=(--export-options-plist="$export_options_plist")
  echo "Using app export profile: $IOS_APP_PROFILE_NAME"
  if [[ -n "${IOS_SHARE_EXTENSION_PROFILE_NAME:-}" ]]; then
    echo "Using Share Extension export profile: $IOS_SHARE_EXTENSION_PROFILE_NAME"
  fi
else
  export_options_args=()
fi

flutter build ipa --release \
  --build-name="$build_name" \
  --build-number="$build_number" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "${export_options_args[@]}" \
  "$@"

shopt -s nullglob
ipa_files=("$ROOT_DIR"/build/ios/ipa/*.ipa)
shopt -u nullglob

if [[ "${#ipa_files[@]}" -eq 0 ]]; then
  echo "Could not find an IPA under $ROOT_DIR/build/ios/ipa" >&2
  exit 1
fi

ipa_path="${ipa_files[0]}"
for candidate in "${ipa_files[@]}"; do
  if [[ "$candidate" -nt "$ipa_path" ]]; then
    ipa_path="$candidate"
  fi
done

if [[ ! "$ipa_path" -nt "$build_started_marker" ]]; then
  echo "No fresh IPA was produced by this build." >&2
  echo "Newest IPA found: $ipa_path" >&2
  exit 1
fi

if [[ "$selected_version" != "$current" ]]; then
  CURRENT="$current" NEXT="$selected_version" perl -0pi -e \
    's/^version:\s*\Q$ENV{CURRENT}\E\s*$/version: $ENV{NEXT}/m' pubspec.yaml

  if ! grep -q "version: $selected_version" pubspec.yaml; then
    echo "Could not update pubspec.yaml from $current to $selected_version" >&2
    exit 1
  fi

  commit_version_change "$selected_version"
fi

echo "IPA output: build/ios/ipa/"
echo "Built TestFlight app version: $build_name"
echo "Built App Store Connect build: $build_number"
echo "Flutter pubspec app+build version: $selected_version"

if [[ "${OPEN_TRANSPORTER:-1}" != "0" ]]; then
  echo "Opening IPA in Transporter: $ipa_path"
  if ! open -a Transporter "$ipa_path"; then
    echo "Transporter is not installed. Install it from the Mac App Store, then open:" >&2
    echo "$ipa_path" >&2
  fi
fi
