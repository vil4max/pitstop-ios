#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "Tooling" ]]; then
  APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

RUNTIME_ROOT="${IOS_AGENT_RUNTIME_ROOT:-$HOME/Developer/Personal/agent-tools/ios-agent-toolchain}"
if [[ ! -d "$RUNTIME_ROOT/scripts" ]]; then
  echo "Runtime root not found: $RUNTIME_ROOT (set IOS_AGENT_RUNTIME_ROOT)" >&2
  exit 1
fi

CURRENT="missing"
if [[ -f "$APP_ROOT/Tooling/.runtime-lock" ]]; then
  CURRENT="$(tr -d '[:space:]' <"$APP_ROOT/Tooling/.runtime-lock")"
fi
# Install only committed Runtime content. Another session's work in progress in the
# Runtime checkout would otherwise land in the app, and the app's commit could not
# say which Runtime it carries.
if git -C "$RUNTIME_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  dirty="$(git -C "$RUNTIME_ROOT" status --porcelain -- Brewfile runtime.manifest.json backend scripts templates docs)"
  if [[ -n "$dirty" ]]; then
    echo "Runtime checkout has uncommitted changes; not installing work in progress:" >&2
    echo "$dirty" | sed 's/^/  /' >&2
    exit 1
  fi
  echo "Source Runtime       $(git -C "$RUNTIME_ROOT" log -1 --format='%h %s')"
fi
LATEST="$("$RUNTIME_ROOT/scripts/runtime-lock.sh" "$RUNTIME_ROOT")"

echo "Current Runtime lock ${CURRENT:0:12}"
echo "Source Runtime lock  ${LATEST:0:12}"

# Prints the first Runtime-managed app file that differs from its template. The lock
# covers only Tooling/, so an app that opts into `pipeline: shared` after its last
# update, or edits a managed file by hand, would otherwise stay "up to date".
managed_drift() {
  grep -qE '^pipeline:[[:space:]]*"?shared"?[[:space:]]*(#.*)?$' "$APP_ROOT/Tooling/runtime.yml" 2>/dev/null || return 0
  local wf project style
  for style in swiftlint.yml:.swiftlint.yml swiftformat:.swiftformat; do
    cmp -s "$RUNTIME_ROOT/templates/${style%%:*}" "$APP_ROOT/Tooling/${style#*:}" || { echo "Tooling/${style#*:}"; return 0; }
  done
  for wf in tests.yml testflight.yml; do
    cmp -s "$RUNTIME_ROOT/templates/github/$wf" "$APP_ROOT/.github/workflows/$wf" || { echo ".github/workflows/$wf"; return 0; }
  done
  while IFS= read -r project; do
    cmp -s "$RUNTIME_ROOT/templates/ci_post_clone.sh" "$(dirname "$project")/ci_scripts/ci_post_clone.sh" \
      || { echo "${project#"$APP_ROOT"/}/../ci_scripts/ci_post_clone.sh"; return 0; }
  done < <(find "$APP_ROOT" -name '*.xcodeproj' -type d -not -path '*/.claude/*' -not -path '*/Tooling/*' -not -path '*/Pods/*' -not -path '*/build/*' -not -path '*/DerivedData/*' -prune)
}

if [[ "$CURRENT" == "$LATEST" ]]; then
  drift="$(managed_drift)"
  if [[ -z "$drift" ]]; then
    echo "Already up to date."
    exit 0
  fi
  echo "Runtime lock unchanged, but $drift differs from its template. Syncing managed files…"
  exec "$RUNTIME_ROOT/scripts/install.sh" "$APP_ROOT" --force
fi

echo "Runtime content differs. Updating Tooling/ slice…"
exec "$RUNTIME_ROOT/scripts/install.sh" "$APP_ROOT" --force
