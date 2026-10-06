# Shared CI and Tag-Gated TestFlight

**Status:** Accepted; tests run on GitHub-hosted runners (public repository)\
**Supersedes:** the "GitHub Actions is disabled" policy in
[`../engineering/quality-and-ci.md`](../engineering/quality-and-ci.md)\
**Contracts:** [`../../Tooling/docs/ci.md`](../../Tooling/docs/ci.md),
[`../../Tooling/docs/testflight.md`](../../Tooling/docs/testflight.md)

## Context

The first TestFlight build (1.0, build 202609211) was archived and uploaded by
hand. That works once, but every later release would repeat the same manual
steps, and nothing ties an uploaded build to a commit whose tests passed.

The installed Runtime in `Tooling/` ships one CI and TestFlight pipeline for
every iOS app that uses it. This app adopts it instead of keeping manual
uploads.

## Decision

- `.github/workflows/tests.yml` and `testflight.yml` are copies of
  `Tooling/templates/github/`, unchanged. What differs between apps is a
  repository variable, never the workflow text, so a fix in the Runtime reaches
  this app through `just harness-update` and a fresh copy.
- The tests job runs on GitHub-hosted `xcode-27` runners; `IOS_RUNNER` stays
  unset and the template picks the hosted image for a public repository.
- A push to `main` runs tests and builds nothing. A TestFlight build is
  requested by an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag on a commit on
  `main` that has its own green tests run; the workflow moves the `testflight`
  branch and Xcode Cloud archives it.
- `ci_scripts/ci_post_clone.sh` sets `CURRENT_PROJECT_VERSION` from
  `CI_BUILD_NUMBER`, so a release needs no build-number commit. The committed
  value (1 for a new `MARKETING_VERSION`) matters only for a manual local
  archive.
- `MARKETING_VERSION` is written as `MAJOR.MINOR.PATCH` (`1.0.0`), because the
  tag gate compares it with the tag's version literally.
- `simulator.os: "27.0"` pins the test runtime: a runner can carry the same
  device name on several iOS runtimes.
- `just verify` stays the local implementation gate. A green hosted run is
  additional evidence, not a replacement for local verification and review.

### Tag authority

- `tf-` tag: the maintainer, after `just tf-check` prints `Ready` for a commit
  already on `origin/main`.
- `v` tag and the App Review submission: the maintainer only.

## Rejected alternatives

- **Manual archive and upload per release.** No link between a build and a
  tested commit, and it needs a signed-in Xcode each time.
- **A build on every push to `main`.** Documentation and tooling commits would
  spend Xcode Cloud compute and upload slots; a per-version upload cap can be
  hit this way.
- **A self-hosted runner.** A public repository must never have one: a pull
  request from a fork could run code on the runner's machine. GitHub-hosted
  runners are free for public repositories.
- **An app-specific workflow.** The reason the shared pipeline exists: separate
  pipelines per app drift, and fixes do not travel between them.

## Setup record

- **Xcode Cloud product "Pitstop"**, one workflow "TestFlight": Restrict
  Editing and Clean on; start condition Branch Changes on `testflight` only (a
  manual start on any branch stays available for rebuilds); one action,
  Archive - iOS with distribution preparation "App Store Connect" (the web
  editor's name for TestFlight and App Store); no test action; post-action
  TestFlight Internal Testing to the group "Internal". Onboarding from Xcode
  creates a default workflow that builds any branch; it was reconfigured into
  this one before the first release.
- **TestFlight group "Internal"**: internal testers from the team, automatic
  distribution on.
- **GitHub**: the Xcode Cloud GitHub app has access to `vil4max/pitstop-ios`;
  rulesets from `Tooling/templates/github/rulesets/` are active.
- **Moving a repository**: a GitHub App grant and the Xcode Cloud primary
  repository are bound to the repository's ID, not its name. After a move the
  product keeps pointing at the old repository and a `testflight` move starts
  nothing, until Xcode Cloud → Settings → Repositories → Change URL re-points
  it. A release whose branch move happened before the fix is rebuilt with Start
  Build on `testflight`, not by retagging.

## First release

`tf-1.0.0-1` on the first public `main` moved `testflight`; Xcode Cloud built
it (manual start, build 2) and TestFlight received 1.0.0 (2) for the
"Internal" group.

App Store Connect files `1.0.0` under the same version as the hand-uploaded
`1.0`: both builds appear under "Version 1.0", and TestFlight kept offering
1.0 (202609211) as the current build because its number is higher than 2. That
build was expired and the next release shipped as `1.1.0`, a version with no
hand-uploaded build, so Xcode Cloud's own numbering starts clean.

## Setup outside the repository

Until these are done, a push runs nothing and a `tf-` tag cannot pass the gate.

1. Enable GitHub Actions for the repository.
2. In App Store Connect, create one Xcode Cloud workflow started by the
   `testflight` branch, with archive distribution **TestFlight and App Store**.
