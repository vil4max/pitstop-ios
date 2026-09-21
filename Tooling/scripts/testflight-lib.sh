#!/usr/bin/env bash
# Shared checks for the tag-gated TestFlight model (docs/testflight.md).
#
# Source this file; it only defines functions. It does not source lib.sh: the
# promotion runs on a GitHub-hosted Linux runner where the Runtime's macOS
# tooling is absent.
#
# A `tf-MAJOR.MINOR.PATCH-BUILD` tag requests one build: the tagged commit must be
# annotated, on main, carry the marketing version the tag names, and have its own
# successful tests run for a push to main. A `vMAJOR.MINOR.PATCH` tag requests
# nothing; it marks the commit whose TestFlight build was submitted.
#
# Remote calls need GH_TOKEN with actions:read and GITHUB_REPOSITORY (both set in
# Actions); locally, gh supplies them or the tests state is reported unknown.

REMOTE="${TF_REMOTE:-origin}"
WAIT_ATTEMPTS="${TF_WAIT_ATTEMPTS:-45}"
WAIT_SECONDS="${TF_WAIT_SECONDS:-60}"
TESTS_WORKFLOW="${TF_TESTS_WORKFLOW:-tests.yml}"
# shellcheck disable=SC2034 # read by tf-check.sh and tf-promote.sh, which source this file
TESTFLIGHT_BRANCH="${TF_BRANCH:-testflight}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

TESTFLIGHT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prints the project file path at commit $1 — `project.pbxproj`, or `project.xcproj`
# in Xcode 27.2's JSON format: TF_PBXPROJ when set, otherwise the single tracked one
# outside dependency directories. Two projects are ambiguous, and guessing would
# check the wrong app's version.
pbxproj_at() {
  local sha="$1" found
  if [[ -n "${TF_PBXPROJ:-}" ]]; then
    echo "$TF_PBXPROJ"
    return 0
  fi
  found="$(git ls-tree -r --name-only "$sha" \
    | grep -E '(^|/)[^/]+\.xcodeproj/project\.(pbxproj|xcproj)$' \
    | grep -vE '(^|/)(Pods|Carthage|\.build|DerivedData|Tooling)/' || true)"
  [[ -n "$found" ]] || fail "no .xcodeproj/project.pbxproj or project.xcproj tracked at ${sha:0:7}; set TF_PBXPROJ"
  [[ "$(wc -l <<<"$found")" -eq 1 ]] \
    || fail "several projects at ${sha:0:7}: $(tr '\n' ' ' <<<"$found")— set TF_PBXPROJ"
  echo "$found"
}

# Prints the distinct MARKETING_VERSION values at commit $1, one per line.
marketing_versions() {
  local sha="$1"
  git show "${sha}:$(pbxproj_at "$sha")" | python3 "$TESTFLIGHT_LIB_DIR/project_versions.py"
}

# Prints the commit of annotated tag $1. A lightweight tag is rejected: the
# annotation is the recorded decision to publish that commit and its What to Test.
resolve_annotated_tag() {
  local tag="$1"
  git fetch --quiet "$REMOTE" "refs/tags/${tag}:refs/tags/${tag}"
  [[ "$(git cat-file -t "refs/tags/${tag}")" == "tag" ]] || fail "$tag must be an annotated tag"
  git rev-list -n 1 "refs/tags/${tag}"
}

# Fails unless every MARKETING_VERSION at commit $2 is exactly $3.
assert_marketing_version() {
  local tag="$1" sha="$2" version="$3" versions
  versions="$(marketing_versions "$sha")"
  [[ "$versions" == "$version" ]] \
    || fail "$tag does not match MARKETING_VERSION at ${sha:0:7}: $(tr '\n' ' ' <<<"$versions")"
}

# Fails unless commit $2 is contained in main.
assert_on_main() {
  local tag="$1" sha="$2"
  git fetch --quiet "$REMOTE" main
  git merge-base --is-ancestor "$sha" FETCH_HEAD || fail "$tag (${sha:0:7}) is not on main"
}

# Prints success, failure, cancelled, pending or missing for the tests runs of a
# push of $1 to main. The API reports each run's latest attempt, so a successful
# rerun replaces an earlier failure or cancellation.
tests_state() {
  gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/${TESTS_WORKFLOW}/runs?head_sha=${1}&event=push&branch=main" \
    --jq '[.workflow_runs[] | {status, conclusion}] as $runs
      | if ($runs | length) == 0 then "missing"
        elif any($runs[]; .conclusion == "success") then "success"
        elif any($runs[]; .status != "completed") then "pending"
        elif all($runs[]; .conclusion == "cancelled") then "cancelled"
        else "failure" end'
}

# Waits until commit $2 has its own successful tests run for a push to main, or
# fails. Containment in a verified branch is no substitute: a red commit followed
# by a green one is contained too. Tagging right after pushing is fine, so this
# waits on "pending" instead of failing.
require_verified_commit() {
  local tag="$1" sha="$2" state attempt
  for ((attempt = 1; ; attempt++)); do
    state="$(tests_state "$sha")"
    case "$state" in
      success)
        echo "${sha:0:7} passed ${TESTS_WORKFLOW} on main"
        return 0
        ;;
      failure)
        fail "${TESTS_WORKFLOW} failed for ${sha:0:7}; fix main and tag the fixed commit"
        ;;
    esac
    # "cancelled": a newer push cancelled this commit's run. "missing": the commit
    # was not the head of its push, so it never had a run of its own.
    if ((attempt >= WAIT_ATTEMPTS)); then
      case "$state" in
        cancelled) fail "${TESTS_WORKFLOW} for ${sha:0:7} was cancelled; rerun it (gh run rerun), then rerun this workflow" ;;
        *) fail "no successful ${TESTS_WORKFLOW} run for a push of ${sha:0:7} to main ($state); tag a commit that was the head of its push" ;;
      esac
    fi
    echo "waiting for ${TESTS_WORKFLOW} on ${sha:0:7}: $state ($attempt/$WAIT_ATTEMPTS)"
    sleep "$WAIT_SECONDS"
  done
}

# Fails unless commit $2 carries a tf-$3-BUILD tag: the build submitted to App
# Review is a TestFlight build of that exact commit. Containment in the testflight
# branch would not show it, since every earlier commit is contained too.
assert_testflight_round() {
  local tag="$1" sha="$2" version="$3" rounds
  rounds="$(git ls-remote --tags "$REMOTE" "refs/tags/tf-${version}-*" \
    | sed -n "s|^${sha}[[:space:]]*refs/tags/\(tf-${version}-[0-9][0-9]*\)\^{}$|\1|p")"
  [[ -n "$rounds" ]] \
    || fail "$tag (${sha:0:7}) carries no tf-${version}-BUILD tag: the submitted build must be a TestFlight build of this commit"
  echo "${sha:0:7} was built for TestFlight as $(tr '\n' ' ' <<<"$rounds")"
}

# Fast-forwards branch $1 to commit $2, named $3 in the log. Never force-pushes:
# the branch is the record of what Xcode Cloud built.
promote_branch() {
  local branch="$1" sha="$2" label="$3"
  if git fetch --quiet "$REMOTE" "$branch" 2>/dev/null && git merge-base --is-ancestor "$sha" FETCH_HEAD; then
    echo "$branch already contains $label"
    # Xcode Cloud starts on a branch change, so a no-op promotion builds nothing;
    # saying so keeps the tag from looking like a build that never arrived.
    echo "$branch did not move, so no build starts; to rebuild ${sha:0:7}, use Start Build on $branch in App Store Connect"
    return 0
  fi
  git push "$REMOTE" "${sha}:refs/heads/${branch}"
  echo "$branch -> $label (${sha:0:7})"
}
