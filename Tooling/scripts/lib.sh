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

# Each app runs on its own simulators, never on a bare device name such as
# "iPhone 17" that every project on the Mac shares: one project's test run shut
# down or took over another's device and detached the owner's live panel. Devices
# are "<Scheme> <device type>" for runs and "<that> Tests" for tests, created on
# demand by sim-device.py. A configured name that is itself a device type is
# treated as the device type.
is_device_type() {
  xcrun simctl list devicetypes 2>/dev/null | sed -n 's/^\(.*\) (com\.apple\..*)$/\1/p' | grep -qxF -- "$1"
}

sim_device_type() {
  local type name
  type="$(cfg_get "simulator.device_type" "")"
  if [[ -z "$type" ]]; then
    name="$(cfg_get "simulator.name" "")"
    if [[ -n "$name" ]] && is_device_type "$name"; then type="$name"; else type="iPhone 17"; fi
  fi
  echo "$type"
}

sim_app_label() {
  local label
  label="$(scheme_name)"
  [[ -n "$label" ]] || label="$(basename "$(project_root)")"
  echo "$label"
}

# One simulator per agent session per app (owner rule, 2026-09-21): sessions of
# different apps and hosts kept attaching to one another's devices and waiting on
# them. A session gets "<host>-<App>-<session id, 8 chars>", used for runs and
# tests alike, and nothing else; the Runtime creates it when missing. The host
# and id come from AGENT_HOST/AGENT_SESSION_ID, else from the Claude desktop
# app's session id (CLAUDE_CODE_HOST_SESSION_ID, "local_<uuid>"), which the app
# lists next to the session's sidebar title so a device maps back to its session,
# else from Claude Code's CLAUDE_CODE_SESSION_ID. Without a session (a person's
# shell, CI) the app-level names below apply.
sim_session_name() {
  local host="${AGENT_HOST:-}" id="${AGENT_SESSION_ID:-}" suffix
  if [[ -z "$id" && -n "${CLAUDE_CODE_HOST_SESSION_ID:-}" ]]; then
    id="${CLAUDE_CODE_HOST_SESSION_ID#local_}"
    host="${host:-claude}"
  elif [[ -z "$id" && -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
    id="$CLAUDE_CODE_SESSION_ID"
    host="${host:-claude}"
  fi
  [[ -n "$id" && "${GITHUB_ACTIONS:-}" != true ]] || return 1
  # Subagents of one session test in parallel in linked worktrees; each worktree
  # keeps its own device so two runs never share one.
  suffix="$(sim_worktree_suffix)"
  suffix="${suffix# · }"
  echo "${host:-agent}-$(sim_app_label)-${id:0:8}${suffix:+-$suffix}"
}

sim_name() {
  local name type
  if sim_session_name >/dev/null; then sim_session_name; return 0; fi
  name="$(cfg_get "simulator.name" "")"
  type="$(sim_device_type)"
  if [[ -z "$name" || "$name" == "$type" ]] || is_device_type "$name"; then
    name="$(sim_app_label) $type"
  fi
  echo "$name"
}

# Worktrees of one app test in parallel (two build slots), so a linked worktree
# gets its own test device: "<name> Tests · <worktree directory>"; CI jobs use
# "<name> Tests · CI". `just sim-clean`
# deletes the devices of worktrees that no longer exist.
sim_worktree_suffix() {
  local root git_dir common
  # A self-hosted runner's checkout is an ordinary clone on the owner's Mac; it
  # must not test on the device the owner's own checkout uses.
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    echo " · CI"
    return 0
  fi
  root="$(project_root)"
  git_dir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null)" || return 0
  common="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  [[ "$git_dir" == "$common" ]] || echo " · $(basename "$root")"
}

sim_test_base_name() {
  cfg_get "simulator.test_name" "$(sim_name) Tests"
}

sim_test_name() {
  if sim_session_name >/dev/null; then sim_session_name; return 0; fi
  echo "$(sim_test_base_name)$(sim_worktree_suffix)"
}

sim_os() {
  cfg_get "simulator.os" ""
}

# A UDID reserves a specific device (runs: simulator.udid; tests:
# simulator.test_udid). UDIDs are machine-specific, so both keys belong in
# Tooling/runtime.local.yml.
sim_udid_configured() {
  cfg_get "simulator.udid" ""
}

# Prints the UDID for role "run" (default) or "test", creating the app's device
# when it does not exist. A reserved UDID that does not exist is an error: falling
# back to another device would restore the collision.
sim_udid() {
  local role="${1:-run}" name reserved
  if [[ "$role" == test ]]; then
    name="$(sim_test_name)"
    reserved="$(cfg_get "simulator.test_udid" "")"
  else
    name="$(sim_name)"
    reserved="$(sim_udid_configured)"
  fi
  # A session uses its own device only: a leftover reservation in
  # runtime.local.yml pointed OneCart's session at its old app-level device.
  if [[ -n "$reserved" ]] && sim_session_name >/dev/null; then
    echo "simulator: ignoring the reserved udid $reserved in this agent session; sessions use only their own device ($name)" >&2
    reserved=""
  fi
  /usr/bin/python3 "$SCRIPT_HOME/sim-device.py" resolve "$name" "$(sim_device_type)" "$(sim_os)" "$reserved"
}

destination_spec() {
  local role="${1:-run}" id name status=0
  id="$(sim_udid "$role")" || status=$?
  if ((status == 0)) && [[ -n "$id" ]]; then
    echo "platform=iOS Simulator,id=${id}"
    return 0
  fi
  # Only a missing simctl may fall back; a missing runtime or reservation is an error.
  ((status == 2)) || return "${status/#0/1}"
  # No simctl to resolve or create a device (a stubbed or non-macOS environment):
  # name the device and let xcodebuild report it.
  [[ "$role" == test ]] && name="$(sim_test_name)" || name="$(sim_name)"
  echo "platform=iOS Simulator,name=${name}"
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
