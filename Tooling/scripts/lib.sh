#!/usr/bin/env bash
set -euo pipefail

SCRIPT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$(dirname "$SCRIPT_HOME")")" == "Tooling" ]]; then
  ROOT="$(cd "$SCRIPT_HOME/../.." && pwd)"
  export TOOLING_ROOT="$ROOT/Tooling"
else
  ROOT="$(cd "$SCRIPT_HOME/.." && pwd)"
  export TOOLING_ROOT="${TOOLING_ROOT:-$ROOT/Tooling}"
fi
export RUNTIME_ROOT="${RUNTIME_ROOT:-$ROOT}"
if [[ -d "$TOOLING_ROOT/backend" ]]; then
  export BACKEND_ROOT="$TOOLING_ROOT/backend"
elif [[ -d "$ROOT/backend" ]]; then
  export BACKEND_ROOT="$ROOT/backend"
else
  export BACKEND_ROOT=""
fi

have() { command -v "$1" >/dev/null 2>&1; }

runtime_config_path() {
  if [[ -f "$TOOLING_ROOT/runtime.yml" ]]; then
    echo "$TOOLING_ROOT/runtime.yml"
  elif [[ -f "$PWD/runtime.yml" ]]; then
    echo "$PWD/runtime.yml"
  elif [[ -f "$RUNTIME_ROOT/templates/runtime.yml" ]]; then
    echo "$RUNTIME_ROOT/templates/runtime.yml"
  else
    echo ""
  fi
}

runtime_local_path() {
  if [[ -f "$TOOLING_ROOT/runtime.local.yml" ]]; then
    echo "$TOOLING_ROOT/runtime.local.yml"
  elif [[ -f "$PWD/runtime.local.yml" ]]; then
    echo "$PWD/runtime.local.yml"
  else
    echo ""
  fi
}

brewfile_path() {
  if [[ -f "$TOOLING_ROOT/Brewfile" ]]; then
    echo "$TOOLING_ROOT/Brewfile"
  elif [[ -f "$ROOT/Brewfile" ]]; then
    echo "$ROOT/Brewfile"
  else
    echo "Brewfile"
  fi
}

cfg_get() {
  local key="$1"
  local default="${2:-}"
  local file local_file
  file="$(runtime_config_path)"
  if [[ -z "$file" ]]; then
    echo "$default"
    return 0
  fi
  if have yq; then
    local v
    # No `// ""` fallback: yq's alternative operator also replaces `false`,
    # which would make boolean keys impossible to disable. Missing keys print
    # `null` and fall through to the default below.
    v="$(yq -r ".$key" "$file" 2>/dev/null || true)"
    local_file="$(runtime_local_path)"
    if [[ -n "$local_file" ]]; then
      local lv
      lv="$(yq -r ".$key" "$local_file" 2>/dev/null || true)"
      if [[ -n "$lv" && "$lv" != "null" ]]; then
        v="$lv"
      fi
    fi
    if [[ -z "$v" || "$v" == "null" ]]; then
      echo "$default"
    else
      echo "$v"
    fi
  else
    echo "$default"
  fi
}

cfg_bool() {
  local key="$1"
  local default="${2:-true}"
  local v
  v="$(cfg_get "$key" "$default")"
  case "$v" in
    true|True|TRUE|yes|1) return 0 ;;
    *) return 1 ;;
  esac
}

project_root() {
  echo "${PROJECT_ROOT:-$PWD}"
}

find_xcodeproj() {
  local root
  root="$(project_root)"
  local explicit
  explicit="$(cfg_get project "")"
  if [[ -n "$explicit" && -e "$root/$explicit" ]]; then
    echo "$root/$explicit"
    return 0
  fi
  local found
  found="$(find "$root" -maxdepth 2 -name '*.xcodeproj' ! -path '*/.*' 2>/dev/null | head -n 1 || true)"
  echo "$found"
}

find_xcworkspace() {
  local root
  root="$(project_root)"
  local explicit
  explicit="$(cfg_get workspace "")"
  if [[ -n "$explicit" && -e "$root/$explicit" ]]; then
    echo "$root/$explicit"
    return 0
  fi
  local found
  found="$(find "$root" -maxdepth 2 -name '*.xcworkspace' ! -path '*/.*' ! -path '*.xcodeproj/*' 2>/dev/null | head -n 1 || true)"
  echo "$found"
}

scheme_name() {
  local s
  s="$(cfg_get scheme "")"
  if [[ -n "$s" ]]; then
    echo "$s"
    return 0
  fi
  local proj
  proj="$(find_xcodeproj)"
  if [[ -n "$proj" ]]; then
    basename "$proj" .xcodeproj
    return 0
  fi
  echo ""
}

sim_name() {
  cfg_get "simulator.name" "iPhone 17"
}

sim_os() {
  cfg_get "simulator.os" ""
}

# A UDID reserves one device for this project. Device names are shared
# machine-wide: two projects on "iPhone 17" run their tests on the same
# simulator, and one session's xcodebuild shuts down or takes over the other's.
# UDIDs are machine-specific, so the key belongs in Tooling/runtime.local.yml.
sim_udid_configured() {
  cfg_get "simulator.udid" ""
}

# Prints the UDID to use: the configured one, else the first available device
# with the configured name, else nothing. A configured UDID that does not exist
# is an error: falling back to the shared name would restore the collision.
sim_udid() {
  local wanted name
  wanted="$(sim_udid_configured)"
  name="$(sim_name)"
  xcrun simctl list devices available -j 2>/dev/null \
    | /usr/bin/python3 -c "
import json, sys
wanted, name, os_version = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    listing = json.load(sys.stdin)
except ValueError:
    # No simctl, or no JSON from it: no device is known, which only matters for a reservation.
    listing = {}
# A runner image can carry the same device name on several iOS runtimes; with
# simulator.os set, only that runtime qualifies (key ends in iOS-27-0 for 27.0).
suffix = 'iOS-' + os_version.replace('.', '-') if os_version else ''
devices = [d for runtime, group in listing.get('devices', {}).items() for d in group
           if d.get('isAvailable', True) and (not suffix or d.get('udid') == wanted or runtime.endswith(suffix))]
if wanted:
    if any(d['udid'] == wanted for d in devices):
        print(wanted)
        raise SystemExit(0)
    sys.stderr.write('simulator.udid %s is not an available device; create it or fix Tooling/runtime.local.yml\\n' % wanted)
    raise SystemExit(3)
for d in devices:
    if d.get('name') == name:
        print(d['udid'])
        break
" "$wanted" "$name" "$(sim_os)"
}

destination_spec() {
  local name os id
  name="$(sim_name)"
  os="$(sim_os)"
  id="$(sim_udid)" || return $?
  if [[ -n "$id" ]]; then
    echo "platform=iOS Simulator,id=${id}"
  elif [[ -n "$os" ]]; then
    echo "platform=iOS Simulator,name=${name},OS=${os}"
  else
    echo "platform=iOS Simulator,name=${name}"
  fi
}

# Xcode asks once per package plugin or macro to "Trust & Enable" it. Agent
# worktrees and CI have no interactive Xcode to answer, so xcodebuild fails
# instead. Skipping validation trusts every plugin and macro the app's package
# graph declares; that is acceptable for the owner's own projects and can be
# disabled per app in runtime.yml. Prints one flag per line.
# Flags for CI runs (CI=true, set by GitHub Actions and self-hosted runners).
# Signing: `adhoc` (default) signs with "-" so a test host keeps Keychain access;
# `none` disables signing for apps whose targets cannot be ad-hoc signed.
# Coverage feeds the job summary; parallel testing is off because clones of the
# simulator on a shared runner are the most common source of flaky failures.
xcodebuild_ci_flags() {
  [[ "${CI:-}" == true ]] || return 0
  case "$(cfg_get ci.signing adhoc)" in
    none) echo CODE_SIGNING_ALLOWED=NO ;;
    *)
      echo CODE_SIGN_IDENTITY=-
      echo DEVELOPMENT_TEAM=
      ;;
  esac
  echo -enableCodeCoverage
  echo YES
  echo -parallel-testing-enabled
  echo NO
}

xcodebuild_validation_flags() {
  if cfg_bool xcodebuild.skip_package_plugin_validation true; then
    echo -skipPackagePluginValidation
  fi
  if cfg_bool xcodebuild.skip_macro_validation true; then
    echo -skipMacroValidation
  fi
}

harness_version() {
  if [[ -f "$TOOLING_ROOT/.runtime-lock" ]]; then
    printf 'lock:%s\n' "$(cut -c1-12 "$TOOLING_ROOT/.runtime-lock")"
  elif [[ -x "$RUNTIME_ROOT/scripts/runtime-lock.sh" ]]; then
    printf 'lock:%s\n' "$("$RUNTIME_ROOT/scripts/runtime-lock.sh" "$RUNTIME_ROOT" | cut -c1-12)"
  else
    echo "lock:missing"
  fi
}

bundle_id_for_scheme() {
  local proj ws scheme settings id
  scheme="$(scheme_name)"
  [[ -n "$scheme" ]] || return 1
  proj="$(find_xcodeproj)"
  ws="$(find_xcworkspace)"
  if [[ -n "$ws" ]]; then
    settings="$(xcodebuild -workspace "$ws" -scheme "$scheme" -showBuildSettings 2>/dev/null || true)"
  elif [[ -n "$proj" ]]; then
    settings="$(xcodebuild -project "$proj" -scheme "$scheme" -showBuildSettings 2>/dev/null || true)"
  else
    return 1
  fi
  id="$(
    printf '%s\n' "$settings" | awk -F' = ' '
      /PRODUCT_TYPE = com.apple.product-type.application/ { app=1 }
      /PRODUCT_BUNDLE_IDENTIFIER/ {
        id=$2
        if (app) { print id; exit }
        if (!first) first=id
      }
      END { if (first != "") print first }
    '
  )"
  [[ -n "$id" ]] || return 1
  echo "$id"
}
