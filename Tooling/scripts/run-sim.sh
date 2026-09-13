#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

usage() {
  cat <<'EOF'
Usage: run-sim.sh [--] [launch-arg ...]

Build with xcodebuild for the configured simulator, install, and launch the app
with optional process launch arguments.

Note: run-sim always uses xcodebuild (needed for a local .app + simctl), even when
Tooling/runtime.yml backend.prefer selects another adapter for just build/test.

Examples:
  just run-sim
  just run-sim -- -ShowPaywall
  just run-sim -- -ScreenshotPhase allClear
EOF
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; ARGS+=("$@"); break ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

SCHEME="$(scheme_name)"
[[ -n "$SCHEME" ]] || { echo "scheme missing — set Tooling/runtime.yml scheme" >&2; exit 1; }

PROJ="$(find_xcodeproj)"
WS="$(find_xcworkspace)"
DEST="$(destination_spec)"
SIM="$(sim_name)"
PREFER="$(cfg_get backend.prefer auto)"
if [[ "$PREFER" != "auto" && "$PREFER" != "xcodebuild" ]]; then
  echo "run-sim: note — backend.prefer=$PREFER is ignored here; run-sim uses xcodebuild for simctl install/launch" >&2
fi

DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/harness-run-sim.XXXXXX")"
cleanup() { rm -rf "$DERIVED"; }
trap cleanup EXIT

XB_ARGS=(-scheme "$SCHEME" -destination "$DEST" -configuration Debug -derivedDataPath "$DERIVED" build)
if [[ -n "$WS" ]]; then
  XB_ARGS=(-workspace "$WS" "${XB_ARGS[@]}")
elif [[ -n "$PROJ" ]]; then
  XB_ARGS=(-project "$PROJ" "${XB_ARGS[@]}")
else
  echo "no .xcodeproj / .xcworkspace found" >&2
  exit 1
fi

echo "run-sim: build $SCHEME → $SIM"
if have xcbeautify; then
  xcodebuild "${XB_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XB_ARGS[@]}"
fi

APP_PATH="$(
  /usr/bin/python3 - "$DERIVED" "$SCHEME" <<'PY'
import os, sys
derived, scheme = sys.argv[1], sys.argv[2]
products = os.path.join(derived, "Build", "Products")
if not os.path.isdir(products):
    raise SystemExit(0)
preferred = []
others = []
for root, dirs, _files in os.walk(products):
    # Prefer top-level products, not nested copies inside other bundles
    depth = root[len(products):].count(os.sep)
    for d in list(dirs):
        if not d.endswith(".app"):
            continue
        path = os.path.join(root, d)
        if depth <= 2:
            (preferred if d == f"{scheme}.app" else others).append(path)
        dirs.remove(d)
if preferred:
    print(preferred[0])
elif others:
    # Prefer iphonesimulator products over others
    others.sort(key=lambda p: (0 if "iphonesimulator" in p else 1, len(p)))
    print(others[0])
PY
)"
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || { echo "no .app produced under $DERIVED (expected ${SCHEME}.app)" >&2; exit 1; }

BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null \
    || plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null \
    || true
)"
[[ -n "$BUNDLE_ID" ]] || { echo "could not read CFBundleIdentifier from $APP_PATH/Info.plist" >&2; exit 1; }

UDID="$(
  xcrun simctl list devices available -j 2>/dev/null \
    | /usr/bin/python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for devices in data.get('devices', {}).values():
    for d in devices:
        if d.get('name') == name and d.get('isAvailable', True):
            print(d['udid'])
            raise SystemExit(0)
" "$SIM" 2>/dev/null || true
)"

echo "run-sim: boot simulator $SIM"
if [[ -n "$UDID" ]]; then
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b
else
  xcrun simctl boot "$SIM" 2>/dev/null || true
fi
open -a Simulator 2>/dev/null || true

TARGET="${UDID:-booted}"
echo "run-sim: install $APP_PATH ($BUNDLE_ID)"
xcrun simctl install "$TARGET" "$APP_PATH"

echo "run-sim: launch $BUNDLE_ID ${ARGS[*]:-}"
if [[ ${#ARGS[@]} -gt 0 ]]; then
  xcrun simctl launch "$TARGET" "$BUNDLE_ID" "${ARGS[@]}"
else
  xcrun simctl launch "$TARGET" "$BUNDLE_ID"
fi

echo "run-sim OK"
