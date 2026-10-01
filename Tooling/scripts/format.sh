#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if ! cfg_bool format true; then
  echo "format skipped (runtime.yml format: false)"
  exit 0
fi

# swift-format ships with the Xcode toolchain; there is nothing to brew install.
if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "swift-format not found: the Xcode toolchain provides it (xcrun --find swift-format failed). Install Xcode 16 or later and select it with xcode-select." >&2
  exit 1
fi

ROOT="$(project_root)"
CONF="$TOOLING_ROOT/.swift-format"
[[ -f "$CONF" ]] || CONF="$ROOT/.swift-format"
[[ -f "$CONF" ]] || CONF="$RUNTIME_ROOT/templates/swift-format"

# swift-format has no exclude option, so it gets an explicit file list: the
# tracked Swift files only. A recursive walk of the root would also format
# Pods, .build, DerivedData and agent worktrees under .claude. The exclusions
# keep those four out even when a project commits them, as the previous
# formatter's config did.
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "format: $ROOT is not a git repository; the Swift file list comes from git ls-files" >&2; exit 1; }
FILES="$(mktemp "${TMPDIR:-/tmp}/swift-format-files.XXXXXX")"
trap 'rm -f "$FILES"' EXIT
git -C "$ROOT" ls-files -z -- '*.swift' \
  ':(exclude,glob)**/Pods/**' ':(exclude,glob)**/.build/**' \
  ':(exclude,glob)**/DerivedData/**' ':(exclude,glob)**/.claude/**' \
  | while IFS= read -r -d '' file; do
  # A tracked file deleted in the work tree is still listed; swift-format would fail on it.
  if [[ -f "$ROOT/$file" ]]; then printf '%s\0' "$file"; fi
done >"$FILES"
# Without a file argument swift-format reads standard input and would hang.
if [[ ! -s "$FILES" ]]; then
  echo "format: no tracked Swift files in $ROOT"
  exit 0
fi

cd "$ROOT"
# CI checks and never rewrites: a rewrite on a runner would pass a commit whose
# committed files are still unformatted. --strict makes every warning fail.
if [[ "${CI:-}" == true ]]; then
  xargs -0 xcrun swift-format lint --strict --parallel --configuration "$CONF" <"$FILES" \
    || { echo "format: swift-format lint failed (see above); run just format and commit the result" >&2; exit 1; }
else
  xargs -0 xcrun swift-format format --in-place --parallel --configuration "$CONF" <"$FILES" \
    || { echo "format: swift-format failed (see above)" >&2; exit 1; }
fi
