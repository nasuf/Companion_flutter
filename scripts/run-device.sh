#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PHYSICAL_DEVICE_ID="${PHYSICAL_DEVICE_ID:-00008130-0008350A3E11001C}"
DEV_API_BASE_URL="${DEV_API_BASE_URL:-https://banshengcomp.com/api}"

flutter run \
  -d "$PHYSICAL_DEVICE_ID" \
  --device-connection attached \
  --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
  "$@"
