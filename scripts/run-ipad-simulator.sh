#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SIMULATOR_DEVICE_ID="${IPAD_SIMULATOR_DEVICE_ID:-7F68F777-D2F2-4FE5-90E8-4A5DA16AE944}"
exec /bin/bash scripts/run-iphone-simulator.sh "$@"
