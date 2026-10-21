#!/usr/bin/env bash
# Publish a verified prod APK, preserving immutable versions and the stable URL.
set -euo pipefail

usage() {
  echo "Usage: $0 [build/android/bansheng-<version>+<build>.apk]"
  echo "Defaults to the current pubspec.yaml version. Requires a current .source.json receipt."
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
source "$(dirname "$0")/fresh-build.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REMOTE_SCRIPT="$SCRIPT_DIR/publish_android_apk_remote.py"
RELEASE_CERT_SHA256="9d9845f19d19dd953edcd1ddd08628a9e5374f1dad12c40df86e61c48243a658"

fail() { echo "Publish failed: $*" >&2; exit 1; }
[[ "$#" -le 1 ]] || { usage >&2; exit 1; }
for tool in python3 jq ssh scp curl shasum; do
  command -v "$tool" >/dev/null || fail "Required tool not found: $tool"
done

# Portable deadline for macOS/Linux. Python only supervises the process group;
# publication decisions and network orchestration remain in this shell script.
run_bounded() {
  python3 -c '
import os, signal, subprocess, sys
process = subprocess.Popen(sys.argv[2:], start_new_session=True)
def kill_group():
    try: os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError: pass
def stop(signum, frame):
    if process.poll() is None: kill_group()
    process.wait()
    sys.exit(128 + signum)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
try:
    status = process.wait(timeout=float(sys.argv[1]))
except subprocess.TimeoutExpired:
    kill_group()
    process.wait()
    print("Command timed out after " + sys.argv[1] + " seconds", file=sys.stderr)
    sys.exit(124)
sys.exit(status if status >= 0 else 128 - status)
' "$@"
}

sha256() { shasum -a 256 < "$1" | awk '{print $1}'; }
android_tool() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}" candidate
  # Select numerically (37.0.0 > 9.0.0); preserve spaces in SDK paths.
  for candidate in "$sdk"/build-tools/*/"$1"; do
    [[ ! -x "$candidate" ]] || printf '%s\n' "$candidate"
  done | jq -Rsr 'split("\n") | map(select(length > 0)) |
    sort_by(split("/")[-2] | [scan("[0-9]+") | tonumber]) | last // error("Android SDK tool missing")'
}
verify_snapshot() {
  python3 "$SCRIPT_DIR/flutter_build_guard.py" verify-snapshot "$apk" "$snapshot"
}

host="${APK_SSH_HOST:-ubuntu@106.52.115.80}"
[[ "$host" != -* && "$host" =~ ^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$ ]] || fail "APK_SSH_HOST must be user@hostname."
port="${APK_SSH_PORT:-22}"
[[ "$port" =~ ^[0-9]{1,5}$ ]] && ((10#$port >= 1 && 10#$port <= 65535)) || fail "Invalid APK_SSH_PORT."
key="${APK_SSH_KEY:-$HOME/.ssh/companion_tencent}"
if [[ "$key" == '~/'* ]]; then key="$HOME/${key:2}"; fi
[[ -f "$key" ]] || fail "SSH identity file missing: $key"
ssh_options=(-i "$key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
base_url="${APK_PUBLIC_BASE_URL:-https://banshengcomp.com/downloads/android}"
while [[ "$base_url" == */ ]]; do base_url="${base_url%/}"; done
jq -en --arg url "$base_url" '$url | test("^https://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$")' >/dev/null \
  || fail "APK_PUBLIC_BASE_URL must be an HTTPS directory URL without credentials/query/fragment."

if [[ "$#" -eq 1 ]]; then
  apk="$1"
else
  version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)[[:space:]]*$/\1/p' "$ROOT_DIR/pubspec.yaml")"
  [[ -n "$version" ]] || fail "Cannot read the current pubspec.yaml version."
  apk="$ROOT_DIR/build/android/bansheng-$version.apk"
fi
[[ -f "$apk" ]] || fail "APK not found: $apk. Run scripts/build-android-apk.sh first."
apk="$(cd "$(dirname "$apk")" && pwd -P)/$(basename "$apk")"

work_dir="$(mktemp -d -t bansheng-apk-publish.XXXXXX)"
stage=""
remote() {
  local action="$1" payload="$2" command
  # @sh provides POSIX quoting for both arguments, including JSON apostrophes.
  command="python3 - $(jq -nr --arg action "$action" --arg payload "$payload" '[$action, $payload] | @sh')"
  run_bounded 90 ssh "${ssh_options[@]}" -p "$port" "$host" "$command" < "$REMOTE_SCRIPT"
}
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$stage" ]]; then
    remote cleanup "$(jq -cn --arg stage "$stage" '{stage:$stage}')" >/dev/null \
      || echo "Warning: remote staging cleanup failed." >&2
  fi
  rm -rf "$work_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

snapshot="$work_dir/upload.apk"
cp "$apk" "$snapshot"
verify_snapshot

aapt="$(android_tool aapt)"
apksigner="$(android_tool apksigner)"
run_bounded 60 "$aapt" dump badging "$snapshot" > "$work_dir/badging.txt"
package="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" "$work_dir/badging.txt")"
build_number="$(sed -n "s/^package:.*versionCode='\([0-9]*\)'.*/\1/p" "$work_dir/badging.txt")"
build_name="$(sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p" "$work_dir/badging.txt")"
[[ "$package" == "com.bansheng.prod" ]] || fail "Only com.bansheng.prod APKs may be published."
if grep -q 'application-debuggable' "$work_dir/badging.txt"; then fail "Debuggable APKs cannot be published."; fi
version="$build_name+$build_number"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || fail "Invalid APK version: $version"
run_bounded 60 "$apksigner" verify --print-certs "$snapshot" > "$work_dir/certs.txt"
signatures="$(sed -nE 's/^Signer #[0-9]+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$/\1/p' "$work_dir/certs.txt" | tr 'A-F' 'a-f')"
[[ "$signatures" == "$RELEASE_CERT_SHA256" ]] || fail "APK is not signed with the approved Bansheng release certificate."
name="bansheng-$version.apk"
[[ "$(basename "$apk")" == "$name" ]] || fail "APK filename must match its embedded version: $name"
digest="$(sha256 "$snapshot")"
size="$(wc -c < "$snapshot" | tr -d '[:space:]')"
url="$base_url/${name//+/%2B}"
download_url="$base_url/bansheng-latest.apk"
qr_name="bansheng-latest.qr.svg"
qr_url="$base_url/$qr_name"

TOOLS_DIR="$ROOT_DIR/build/android/.publish-venv"
if [[ ! -x "$TOOLS_DIR/bin/python" ]]; then python3 -m venv "$TOOLS_DIR"; fi
if ! "$TOOLS_DIR/bin/python" -c 'from importlib.metadata import version; assert version("qrcode") == "8.2"' 2>/dev/null; then
  run_bounded 300 "$TOOLS_DIR/bin/python" -m pip install --disable-pip-version-check -r "$SCRIPT_DIR/requirements-android-publish.txt"
fi
make_qr() {
  # Keep the exact encoder/version/options: the published SVG is immutable.
  "$TOOLS_DIR/bin/python" - "$download_url" "$1" <<'PY'
import sys
import qrcode
from qrcode.image.svg import SvgPathFillImage
qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=4)
qr.add_data(sys.argv[1])
qr.make(fit=True)
if sys.argv[2]:
    qr.make_image(image_factory=SvgPathFillImage).save(sys.argv[2])
else:
    qr.print_ascii(tty=sys.stdout.isatty(), invert=True)
PY
}
make_qr "$work_dir/qr.svg"
qr_digest="$(sha256 "$work_dir/qr.svg")"
echo "Verified prod release $version, $size bytes, SHA-256 $digest"

remote prepare "$(jq -cn --argjson size "$size" '{size:$size}')" > "$work_dir/prepare.json"
stage="$(jq -er '.stage | strings' "$work_dir/prepare.json")"
if [[ ! "$stage" =~ ^/mnt/datadisk0/companion/downloads/\.android-upload-[a-zA-Z0-9_]+$ ]]; then
  stage=""
  fail "Invalid remote staging path."
fi
echo "Uploading to the Tencent data disk…"
run_bounded 900 scp "${ssh_options[@]}" -P "$port" "$snapshot" "$host:$stage/upload.apk"
run_bounded 60 scp "${ssh_options[@]}" -P "$port" "$work_dir/qr.svg" "$host:$stage/qr.svg"
verify_snapshot
remote publish "$(jq -cn --arg stage "$stage" --arg name "$name" --arg sha256 "$digest" \
  --argjson size "$size" --arg qr_sha256 "$qr_digest" \
  '{stage:$stage,name:$name,sha256:$sha256,size:$size,qr_sha256:$qr_sha256}')" > "$work_dir/publish.json"
remote_path="$(jq -er '.path | strings' "$work_dir/publish.json")"
[[ "$remote_path" == "/mnt/datadisk0/companion/downloads/android/$name" ]] || fail "Unexpected published APK path."

fetch_file() {
  local source_url="$1" destination="$2" mime="$3" timeout="$4" response
  response="$(curl --fail --silent --show-error --proto '=https' --connect-timeout 15 \
    --max-time "$timeout" --output "$destination" --write-out '%{http_code}\n%{content_type}' "$source_url")"
  [[ "${response%%$'\n'*}" == "200" ]] || fail "Public download failed HTTP status verification: $source_url"
  if [[ -n "$mime" && "$response" != "200"$'\n'"$mime" ]]; then
    fail "Public download failed MIME verification: $source_url"
  fi
}
echo "Verifying full HTTPS download…"
fetch_file "$url?sha256=$digest" "$work_dir/download.apk" application/vnd.android.package-archive 900
[[ "$(sha256 "$work_dir/download.apk")" == "$digest" ]] || fail "Public APK download SHA-256 mismatch."
fetch_file "$url.sha256" "$work_dir/checksum" "" 30
printf '%s  %s\n' "$digest" "$name" > "$work_dir/expected-checksum"
cmp -s "$work_dir/checksum" "$work_dir/expected-checksum" || fail "Public checksum file does not match the APK."
fetch_file "$qr_url" "$work_dir/download.svg" image/svg+xml 30
[[ "$(sha256 "$work_dir/download.svg")" == "$qr_digest" ]] || fail "Public QR code SHA-256 mismatch."

jq -n --arg version "$version" --arg filename "$name" --arg qr_filename "$qr_name" \
  --arg sha256 "$digest" --arg qr_sha256 "$qr_digest" --argjson size_bytes "$size" \
  --arg url "$url" --arg qr_url "$qr_url" --arg download_url "$download_url" \
  '{schema_version:1,version:$version,filename:$filename,qr_filename:$qr_filename,sha256:$sha256,
    qr_sha256:$qr_sha256,size_bytes:$size_bytes,url:$url,qr_url:$qr_url,download_url:$download_url}' > "$work_dir/release.json"
verify_snapshot
remote activate "$(jq -c '{release:.}' "$work_dir/release.json")" > "$work_dir/activated.json"
latest_url="$base_url/latest.json"
fetch_file "$latest_url" "$work_dir/latest.json" "" 30
jq -e --slurpfile expected "$work_dir/release.json" \
  '. as $actual | $expected[0] | to_entries | all(.[]; . as $field | $actual[$field.key] == $field.value)' \
  "$work_dir/latest.json" >/dev/null || fail "Public latest.json does not match the verified release."
fetch_file "$download_url" "$work_dir/latest.apk" application/vnd.android.package-archive 900
[[ "$(sha256 "$work_dir/latest.apk")" == "$digest" ]] || fail "Stable APK download SHA-256 mismatch."

receipt="$apk.publish.json"
jq --arg package com.bansheng.prod --arg certificate_sha256 "$RELEASE_CERT_SHA256" \
  --arg latest_url "$latest_url" --arg remote_path "$remote_path" \
  '{version,package:$package,url,sha256,size_bytes,certificate_sha256:$certificate_sha256,
    download_url,qr_url,qr_sha256,latest_url:$latest_url,remote_path:$remote_path,verified_at:(now|todateiso8601)}' \
  "$work_dir/release.json" > "$work_dir/receipt.json"
cp "$work_dir/qr.svg" "$(dirname "$apk")/$qr_name"
cp "$work_dir/receipt.json" "$receipt"
echo "Published and verified: $url"
echo "Latest download (permanent): $download_url"
echo "QR code: $qr_url"
echo "Scan to download:"
make_qr ""
echo "Local QR code: $(dirname "$apk")/$qr_name"
echo "Receipt: $receipt"
