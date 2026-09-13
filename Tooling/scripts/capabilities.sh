#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# Cursor sessions expose these markers; xcode-tools MCP is required only there.
is_cursor_host() {
  [[ -n "${CURSOR_TRACE_ID:-}" || -n "${CURSOR_AGENT:-}" ]]
}

cap_json_obj() {
  local configured="$1" available="$2" healthy="$3"
  printf '{"configured":%s,"available":%s,"healthy":%s}' "$configured" "$available" "$healthy"
}

check_bin() {
  local name="$1"
  if have "$name"; then
    cap_json_obj true true true
  else
    cap_json_obj false false false
  fi
}

xcodebuild_cap() {
  if ! have xcodebuild; then
    cap_json_obj false false false
    return 0
  fi
  if xcodebuild -version >/dev/null 2>&1; then
    cap_json_obj true true true
  else
    cap_json_obj true true false
  fi
}

swift_cap() {
  check_bin swift
}

simulator_cap() {
  if ! have xcrun; then
    cap_json_obj false false false
    return 0
  fi
  local name
  name="$(sim_name)"
  if xcrun simctl list devices available 2>/dev/null | grep -q "$name"; then
    cap_json_obj true true true
  else
    cap_json_obj true true false
  fi
}

mcp_json_path() {
  echo "${CURSOR_MCP_JSON:-$HOME/.cursor/mcp.json}"
}

xcode_tools_configured() {
  local f
  f="$(mcp_json_path)"
  [[ -f "$f" ]] || return 1
  if have jq; then
    jq -e '.mcpServers["xcode-tools"] != null or .mcpServers["user-xcode-tools"] != null' "$f" >/dev/null 2>&1
  else
    grep -q 'xcode-tools' "$f" 2>/dev/null
  fi
}

xcodebuild_mcp_configured() {
  local f
  f="$(mcp_json_path)"
  [[ -f "$f" ]] || return 1
  if have jq; then
    jq -e '.mcpServers["XcodeBuildMCP"] != null or .mcpServers["user-XcodeBuildMCP"] != null' "$f" >/dev/null 2>&1
  else
    grep -qi 'xcodebuildmcp' "$f" 2>/dev/null
  fi
}

xcode_tools_cap() {
  local configured=false available=false healthy=false
  if xcode_tools_configured; then
    configured=true
    available=true
  fi
  if have xcrun && xcrun mcpbridge --help >/dev/null 2>&1; then
    available=true
  fi
  # Healthy only when an Xcode project is present in cwd — still may need Xcode open;
  # without project we mark not healthy (empty toolset is expected).
  local proj
  proj="$(find_xcodeproj)"
  if [[ "$configured" == true && -n "$proj" ]]; then
    # Soft healthy: project exists; real toolset needs Xcode UI open (documented warning)
    healthy=false
  fi
  cap_json_obj "$configured" "$available" "$healthy"
}

xcodebuild_mcp_cap() {
  local configured=false available=false healthy=false
  if xcodebuild_mcp_configured; then
    configured=true
    available=true
  fi
  if have npx; then
    available=true
  fi
  # Execute via this provider is opt-in; never auto-healthy
  healthy=false
  cap_json_obj "$configured" "$available" "$healthy"
}

emit_capabilities_json() {
  printf '{'
  printf '"xcodebuild":%s,' "$(xcodebuild_cap)"
  printf '"swift":%s,' "$(swift_cap)"
  printf '"simulator":%s,' "$(simulator_cap)"
  printf '"swiftlint":%s,' "$(check_bin swiftlint)"
  printf '"swiftformat":%s,' "$(check_bin swiftformat)"
  printf '"just":%s,' "$(check_bin just)"
  printf '"git":%s,' "$(check_bin git)"
  printf '"gh":%s,' "$(check_bin gh)"
  printf '"yq":%s,' "$(check_bin yq)"
  printf '"xcbeautify":%s,' "$(check_bin xcbeautify)"
  printf '"host.xcode_tools":%s,' "$(xcode_tools_cap)"
  printf '"build.xcodebuild_mcp":%s' "$(xcodebuild_mcp_cap)"
  printf '}'
}

select_build_backend() {
  local prefer
  prefer="$(cfg_get backend.prefer auto)"
  case "$prefer" in
    xcodebuild) echo xcodebuild ;;
    xcode_tools)
      if [[ "$(xcode_tools_cap | jq -r .healthy 2>/dev/null || echo false)" == true ]]; then
        echo xcode_tools
      else
        echo xcodebuild
      fi
      ;;
    xcodebuild_mcp|mcp)
      if [[ "$(xcodebuild_mcp_cap | jq -r .healthy 2>/dev/null || echo false)" == true ]]; then
        echo xcodebuild_mcp
      else
        echo xcodebuild
      fi
      ;;
    swiftpm)
      echo swiftpm
      ;;
    auto|*)
      echo xcodebuild
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-json}" in
    json) emit_capabilities_json ; echo ;;
    backend) select_build_backend ;;
    *) echo "usage: capabilities.sh [json|backend]" >&2; exit 2 ;;
  esac
fi
