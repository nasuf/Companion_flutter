#!/usr/bin/env bash
# Upload the current prod release APK; validates signing and the public download.
set -euo pipefail
exec python3 "$(dirname "$0")/publish_android_apk.py" "$@"
