#!/usr/bin/env bash
# Upload the current prod release APK; validates signing and the public download.
set -euo pipefail
source "$(dirname "$0")/fresh-build.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/../build/android/.publish-venv"
if [[ ! -x "$TOOLS_DIR/bin/python" ]]; then
  python3 -m venv "$TOOLS_DIR"
fi
if ! "$TOOLS_DIR/bin/python" -c 'from importlib.metadata import version; assert version("qrcode") == "8.2"' 2>/dev/null; then
  "$TOOLS_DIR/bin/python" -m pip install --disable-pip-version-check -r "$SCRIPT_DIR/requirements-android-publish.txt"
fi
exec "$TOOLS_DIR/bin/python" "$SCRIPT_DIR/publish_android_apk.py" "$@"
