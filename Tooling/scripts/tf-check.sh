#!/usr/bin/env bash
# Checks a commit against the tf- tag rules and prints the tag to push.
#
# Usage: just tf-check [<commit-ish>]   (default: HEAD)
#
# A rejected tag has to be deleted locally and remotely before retrying, and an
# unwanted build spends one of the day's App Store Connect uploads (the cap behind
# ITMS-90382). So the workflow's own checks run here first, and the exact tag with
# the next free BUILD number is printed only when nothing blocks it. An agent may
# push that tag after "Ready"; a `v` tag and App Review submission stay with the
# owner (docs/testflight.md).
#
# Read-only: it fetches but never tags or pushes. gh is optional — without it the
# tests state is reported as unknown, and unknown is not ready.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=testflight-lib.sh
. "${SCRIPT_DIR}/testflight-lib.sh"

target="${1:-HEAD}"
blocked=0

note() { printf '  %s\n' "$*"; }
ok() { printf 'ok       %s\n' "$*"; }
blocks() {
  printf 'blocked  %s\n' "$*"
  blocked=1
}

sha="$(git rev-parse "${target}^{commit}")"
printf 'commit   %s  %s\n' "${sha:0:7}" "$(git log -1 --format=%s "$sha")"

git fetch --quiet "$REMOTE" main
if git merge-base --is-ancestor "$sha" FETCH_HEAD; then
  ok "on main"
else
  blocks "not on $REMOTE/main — push it first; a tag on an unpushed commit is rejected"
fi

versions="$(marketing_versions "$sha")"
version="$(head -1 <<<"$versions")"
if [[ -z "$version" ]]; then
  blocks "no MARKETING_VERSION in $(pbxproj_at "$sha")"
elif [[ "$(wc -l <<<"$versions")" -eq 1 ]]; then
  ok "MARKETING_VERSION $version in every target and configuration"
else
  blocks "MARKETING_VERSION differs across targets or configurations: $(tr '\n' ' ' <<<"$versions")"
fi

# The next free BUILD comes from the remote's tags: local tags can be stale or
# missing in a fresh clone or a worktree.
next=1
while read -r existing; do
  [[ -n "$existing" ]] || continue
  ((existing >= next)) && next=$((existing + 1))
done < <(git ls-remote --tags "$REMOTE" "refs/tags/tf-${version}-*" \
  | sed -n 's|.*refs/tags/tf-'"${version}"'-\([0-9][0-9]*\)$|\1|p')
tag="tf-${version}-${next}"

if [[ -z "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
  GITHUB_REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  export GITHUB_REPOSITORY
fi
if [[ -n "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
  case "$(tests_state "$sha")" in
    success) ok "${TESTS_WORKFLOW} passed for a push of this commit to main" ;;
    pending) blocks "${TESTS_WORKFLOW} is still running for this commit — rerun tf-check when it finishes" ;;
    failure) blocks "${TESTS_WORKFLOW} failed for this commit — fix forward on main and tag the fix" ;;
    cancelled) blocks "${TESTS_WORKFLOW} was cancelled for this commit — rerun it (gh run rerun)" ;;
    missing) blocks "no ${TESTS_WORKFLOW} run for a push of this commit to main — it was not the head of its push" ;;
    *) blocks "could not read the ${TESTS_WORKFLOW} runs for this commit" ;;
  esac
else
  # An agent tags only after "Ready", so an unknown state must block, not warn.
  blocks "tests state unknown (gh missing or not signed in) — cannot confirm this commit's own ${TESTS_WORKFLOW} run"
fi

if git fetch --quiet "$REMOTE" "$TESTFLIGHT_BRANCH" 2>/dev/null && git merge-base --is-ancestor "$sha" FETCH_HEAD; then
  blocks "$TESTFLIGHT_BRANCH already contains this commit — the branch would not move and no build would start"
  note "to rebuild it, use Start Build on $TESTFLIGHT_BRANCH in App Store Connect; it needs no tag"
fi

echo
if ((blocked)); then
  echo "Not ready to tag. Fix the blocked lines above."
  exit 1
fi
cat <<TAG
Ready. Round $next of $version:

  git tag -a -F <what-to-test.txt> $tag ${sha:0:12}
  git push $REMOTE $tag

The annotation is this round's What to Test: a checklist of observable pass/fail
behavior plus what was not verified. Paste it into App Store Connect when the
build appears.
TAG
