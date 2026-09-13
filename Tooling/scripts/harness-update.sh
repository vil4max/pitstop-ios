#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "Tooling" ]]; then
  APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

RUNTIME_ROOT="${IOS_AGENT_RUNTIME_ROOT:-$HOME/Developer/Personal/ios-agent-toolchain}"
if [[ ! -d "$RUNTIME_ROOT/scripts" ]]; then
  echo "Runtime root not found: $RUNTIME_ROOT (set IOS_AGENT_RUNTIME_ROOT)" >&2
  exit 1
fi

CURRENT="missing"
if [[ -f "$APP_ROOT/Tooling/.runtime-lock" ]]; then
  CURRENT="$(tr -d '[:space:]' <"$APP_ROOT/Tooling/.runtime-lock")"
fi
LATEST="$("$RUNTIME_ROOT/scripts/runtime-lock.sh" "$RUNTIME_ROOT")"

echo "Current Runtime lock ${CURRENT:0:12}"
echo "Source Runtime lock  ${LATEST:0:12}"

if [[ "$CURRENT" == "$LATEST" ]]; then
  echo "Already up to date."
  exit 0
fi

echo "Runtime content differs. Updating Tooling/ slice…"
exec "$RUNTIME_ROOT/scripts/install.sh" "$APP_ROOT" --force
