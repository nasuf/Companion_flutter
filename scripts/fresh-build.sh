#!/usr/bin/env bash
# Sourced by every Flutter build/run entry point. Keep the lock outside build/.
if [[ "${COMPANION_BUILD_SCRIPT:-}" != "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" ]]; then
  exec python3 "$(dirname "$0")/flutter_build_guard.py" lock "$0" "$@"
fi

fresh_build_prepare() {
  echo "Building current local source in: $PWD"
  flutter clean
  python3 scripts/flutter_build_guard.py assert-clean
  flutter pub get
}

fresh_build_fingerprint() {
  python3 scripts/flutter_build_guard.py fingerprint
}

fresh_build_seal() {
  python3 scripts/flutter_build_guard.py seal "$1" "$2"
}

fresh_build_verify() {
  python3 scripts/flutter_build_guard.py verify "$1"
}

# Build first, then launch that verified binary. Preserve runtime options and
# compiler settings needed by the debug frontend server for hot reload.
fresh_build_run_options() {
  build_extra=(--no-pub)
  run_extra=(--no-pub)
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --route|--device-user|--device-timeout|--device-connection|--host-vmservice-port|--device-vmservice-port|--dds-port|--pid-file)
        [[ "$#" -ge 2 ]] || { echo "Missing value for $1" >&2; return 1; }
        run_extra+=("$1" "$2"); shift 2 ;;
      --route=*|--device-user=*|--device-timeout=*|--device-connection=*|--host-vmservice-port=*|--device-vmservice-port=*|--dds-port=*|--pid-file=*|--resident|--no-resident|--hot|--no-hot|--start-paused|--no-start-paused)
        run_extra+=("$1"); shift ;;
      --dart-define|--dart-define-from-file|--target|-D|-t)
        [[ "$#" -ge 2 ]] || { echo "Missing value for $1" >&2; return 1; }
        build_extra+=("$1" "$2"); run_extra+=("$1" "$2"); shift 2 ;;
      --dart-define=*|--dart-define-from-file=*|--target=*|-D*|-t*|*.dart)
        build_extra+=("$1"); run_extra+=("$1"); shift ;;
      *) build_extra+=("$1"); shift ;;
    esac
  done
}
