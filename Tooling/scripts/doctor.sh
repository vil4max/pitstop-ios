#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

JSON=false
for a in "$@"; do
  [[ "$a" == "--json" ]] && JSON=true
done

CAPS="$(emit_capabilities_json)"
BACKEND="$(select_build_backend)"
VERSION="$(harness_version)"
WARNINGS=()
CHECKS=()
OK=true

cap_field() {
  local name="$1" field="$2"
  if have jq; then
    echo "$CAPS" | jq -r --arg n "$name" --arg f "$field" '.[$n][$f]'
  else
    echo false
  fi
}

add_check() {
  local id="$1" ok="$2" msg="$3"
  CHECKS+=("$(printf '{"id":"%s","ok":%s,"message":"%s"}' "$id" "$ok" "$msg")")
  if [[ "$ok" != true ]]; then
    OK=false
  fi
}

xb="$(cap_field xcodebuild healthy)"
if [[ "$xb" == true ]]; then
  add_check xcodebuild true "xcodebuild healthy"
else
  add_check xcodebuild false "xcodebuild missing or unhealthy"
fi

sw="$(cap_field swift available)"
if [[ "$sw" == true ]]; then
  add_check swift true "swift available"
else
  add_check swift false "swift missing"
fi

sim="$(cap_field simulator healthy)"
if [[ "$sim" == true ]]; then
  add_check simulator true "simulator $(sim_name) available"
else
  WARNINGS+=("simulator $(sim_name) not found or unhealthy")
  add_check simulator true "simulator soft — warning only"
fi

xtc="$(cap_field host.xcode_tools configured)"
if [[ "$xtc" == true ]]; then
  add_check host.xcode_tools.configured true "Apple xcode-tools MCP configured"
elif is_cursor_host; then
  # Documented contract: required on Cursor hosts only.
  add_check host.xcode_tools.configured false "enable Apple xcode-tools MCP in Cursor"
else
  WARNINGS+=("xcode-tools MCP not configured — optional outside Cursor")
  add_check host.xcode_tools.configured true "xcode-tools MCP optional: not a Cursor session"
fi

xth="$(cap_field host.xcode_tools healthy)"
if [[ "$xtc" == true && "$xth" != true ]]; then
  WARNINGS+=("xcode-tools configured but not healthy for execute (open Xcode with project); using xcodebuild")
fi

scheme="$(scheme_name)"
if [[ -n "$scheme" ]]; then
  add_check scheme true "scheme=$scheme"
else
  WARNINGS+=("scheme not resolved — set Tooling/runtime.yml scheme")
  add_check scheme true "scheme soft until configured"
fi

if ! have yq; then
  WARNINGS+=("yq missing — install via Brewfile for Tooling/runtime.yml")
fi

CHECKS_JSON="["
for i in "${!CHECKS[@]}"; do
  [[ $i -gt 0 ]] && CHECKS_JSON+=","
  CHECKS_JSON+="${CHECKS[$i]}"
done
CHECKS_JSON+="]"

WARN_JSON="["
if have jq; then
  for i in "${!WARNINGS[@]}"; do
    [[ $i -gt 0 ]] && WARN_JSON+=","
    WARN_JSON+=$(printf '%s' "${WARNINGS[$i]}" | jq -Rs .)
  done
fi
WARN_JSON+="]"

if $JSON; then
  if have jq; then
    jq -n \
      --argjson ok "$OK" \
      --arg version "$VERSION" \
      --argjson capabilities "$CAPS" \
      --arg backend "$BACKEND" \
      --argjson checks "$CHECKS_JSON" \
      --argjson warnings "$WARN_JSON" \
      '{ok:$ok,version:$version,capabilities:$capabilities,build_backend_selected:$backend,checks:$checks,warnings:$warnings}'
  else
    echo "{\"ok\":$OK,\"version\":\"$VERSION\",\"build_backend_selected\":\"$BACKEND\"}"
  fi
else
  echo "iOS Agent Runtime doctor (v$VERSION)"
  echo "backend: $BACKEND"
  echo "ok: $OK"
  for c in "${CHECKS[@]}"; do
    if have jq; then
      echo "$c" | jq -r '"  [" + (if .ok then "OK" else "FAIL" end) + "] " + .id + " — " + .message'
    else
      echo "  $c"
    fi
  done
  for w in "${WARNINGS[@]}"; do
    echo "  [WARN] $w"
  done
fi

$OK
