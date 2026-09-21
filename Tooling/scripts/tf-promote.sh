#!/usr/bin/env bash
# Moves the testflight branch to the verified commit a tf- tag names, or checks a
# v marker tag. Runs in GitHub Actions (templates/github/testflight.yml).
#
# Usage: Tooling/scripts/tf-promote.sh <tf-MAJOR.MINOR.PATCH-BUILD | vMAJOR.MINOR.PATCH>
#
# Xcode Cloud builds internal TestFlight builds from the testflight branch. Every
# build costs Xcode Cloud compute and an App Store Connect upload slot, so a
# commit reaches the branch only through a tag: annotated, naming the commit's own
# MARKETING_VERSION, on main, with a successful tests run for a push of that exact
# commit to main. Tagging right after pushing is fine: the script waits. A v tag
# moves nothing; it is checked to name a commit that has its own TestFlight round.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=testflight-lib.sh
. "${SCRIPT_DIR}/testflight-lib.sh"

TAG="${1:-}"
[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY is not set"

if [[ "$TAG" =~ ^tf-([0-9]+\.[0-9]+\.[0-9]+)-[0-9]+$ ]]; then
  version="${BASH_REMATCH[1]}"
  sha="$(resolve_annotated_tag "$TAG")"
  assert_marketing_version "$TAG" "$sha" "$version"
  assert_on_main "$TAG" "$sha"
  require_verified_commit "$TAG" "$sha"
  promote_branch "$TESTFLIGHT_BRANCH" "$sha" "$TAG"
elif [[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  version="${BASH_REMATCH[1]}"
  sha="$(resolve_annotated_tag "$TAG")"
  assert_marketing_version "$TAG" "$sha" "$version"
  assert_on_main "$TAG" "$sha"
  require_verified_commit "$TAG" "$sha"
  assert_testflight_round "$TAG" "$sha" "$version"
  echo "$TAG marks ${sha:0:7} as the submitted commit of $version"
else
  fail "tag '$TAG' is neither tf-MAJOR.MINOR.PATCH-BUILD nor vMAJOR.MINOR.PATCH"
fi
