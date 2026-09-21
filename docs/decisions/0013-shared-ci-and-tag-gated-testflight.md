# Shared CI and Tag-Gated TestFlight

**Status:** Accepted (owner decision, 2026-09-21); the runner choice is
superseded by [ADR 0014](0014-public-repository.md)\
**Supersedes:** the "GitHub Actions is disabled" policy in
[`../engineering/quality-and-ci.md`](../engineering/quality-and-ci.md)\
**Contracts:** [`../../Tooling/docs/ci.md`](../../Tooling/docs/ci.md),
[`../../Tooling/docs/testflight.md`](../../Tooling/docs/testflight.md)

## Context

The first TestFlight build (1.0, build 202609211) was archived and uploaded by
hand from the owner's Mac. That works once, but every later round would repeat
the same manual steps, and nothing ties an uploaded build to a commit whose
tests passed.

The Runtime now ships one CI and TestFlight pipeline for every iOS app on it
(`ios-agent-toolchain` dbad0e2). The owner chose to adopt it here instead of
keeping manual uploads.

## Decision

- `.github/workflows/tests.yml` and `testflight.yml` are copies of
  `Tooling/templates/github/`, unchanged. What differs between apps is a
  repository variable, never the workflow text, so a fix in the Runtime reaches
  this app through `just harness-update` and a fresh copy.
- The repository is private, so the tests job runs on a **self-hosted runner on
  the owner's Mac** (the default label for a private repository). Hosted macOS minutes are billed
  at ten times the Linux rate; the self-hosted runner shares the machine-wide
  build slots with local sessions.
- A push to `main` runs tests and builds nothing. A TestFlight build is
  requested by an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag on a commit on
  `main` that has its own green tests run; the workflow moves the `testflight`
  branch and Xcode Cloud archives it.
- `ci_scripts/ci_post_clone.sh` sets `CURRENT_PROJECT_VERSION` from
  `CI_BUILD_NUMBER`, so a round needs no build-number commit. The committed
  value follows the owner's rule (1 for a new `MARKETING_VERSION`) and matters
  only for a manual local archive.
- `MARKETING_VERSION` is written as `MAJOR.MINOR.PATCH` (`1.0.0`), because the
  tag gate compares it with the tag's version literally.
- `simulator.os: "27.0"` pins the test runtime: a runner can carry the same
  device name on several iOS runtimes.
- `just verify` stays the local implementation gate. A green hosted run is
  additional evidence, not a replacement for local verification and review.

### Tag authority

- `tf-` tag: the owner, or an agent after `just tf-check` prints `Ready` for a
  commit already on `origin/main`.
- `v` tag and the App Review submission: the owner only.

## Rejected alternatives

- **Manual archive and upload per round.** No link between a build and a tested
  commit, and it needs the owner's signed-in Xcode each time.
- **A build on every push to `main`.** Documentation and tooling commits would
  spend Xcode Cloud compute and upload slots; Drive Check hit the per-version
  upload cap this way.
- **GitHub-hosted macOS runners.** Billed minutes for a solo private project,
  with no benefit over the Mac that already runs the gate.
- **An app-specific workflow.** The reason the shared pipeline exists: three
  apps had three pipelines, and fixes did not travel between them.

## Setup record (2026-09-21)

The runner steps above this record were superseded the same day by the public
repository ([ADR 0014](0014-public-repository.md)): tests run on GitHub-hosted
runners and no self-hosted runner exists.

- **Xcode Cloud product "Pitstop"**, one workflow "TestFlight": Restrict
  Editing and Clean on; start condition Branch Changes on `testflight` only (a
  manual start on any branch stays available for rebuilds); one action,
  Archive - iOS with distribution preparation "App Store Connect" (the web
  editor's name for TestFlight and App Store); no test action; post-action
  TestFlight Internal Testing to the group "Internal". Onboarding from Xcode
  created a default workflow that built any branch; it was reconfigured into
  this one before the first round.
- **TestFlight group "Internal"**: internal testers from the team, automatic
  distribution on.
- **GitHub**: the Xcode Cloud GitHub app has access to `vil4max/pitstop-ios`;
  rulesets from `Tooling/templates/github/rulesets/` are active.
- **Moving a repository**: a GitHub App grant and the Xcode Cloud primary
  repository are bound to the repository's ID, not its name. After the move to
  the new public repository the product kept pointing at the deleted one, and a
  `testflight` move started nothing, until Xcode Cloud → Settings →
  Repositories → Change URL re-pointed it. A round whose branch move happened
  before the fix is rebuilt with Start Build on `testflight`, not by retagging.

## First round

`tf-1.0.0-1` on the first public `main` moved `testflight`; after the
repository fix above, Xcode Cloud built it (manual start, build 2) and
TestFlight received 1.0.0 (2) for the "Internal" group. App Store Connect
accepted build 2 although a hand-uploaded 1.0 (202609211) exists: it tracks
`1.0.0` as a separate version, so the risk recorded below did not occur.

## Owner setup (outside the repository)

Until these are done, a push runs nothing and a `tf-` tag cannot pass the gate.
Since Runtime 39e7b64 the tests workflow defaults a private repository to the
`self-hosted` label, so a push without a runner waits instead of landing on a
billed GitHub-hosted macOS image; `IOS_RUNNER` is needed only to override that.

1. Register the self-hosted runner (done 2026-09-21: `MacBook-Maxim-pitstop`,
   service in `~/actions-runner/pitstop-ios`) and set
   `IOS_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
   (`Tooling/docs/ci.md`, "Self-hosted runner on this Mac").
2. Enable GitHub Actions for the repository.
3. In App Store Connect, create one Xcode Cloud workflow started by the
   `testflight` branch, with archive distribution **TestFlight and App Store**.

## Risk

The manual build was uploaded as version `1.0`. If App Store Connect treats
`1.0.0` as the same version, Xcode Cloud's build numbers must stay above
202609211; set the workflow's next build number accordingly before the first
round.
