# Shared CI and Tag-Gated TestFlight

**Status:** Accepted (owner decision, 2026-09-21)\
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
  the owner's Mac** (`IOS_RUNNER=self-hosted`). Hosted macOS minutes are billed
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

## Owner setup (outside the repository)

Until these are done, a push runs nothing and a `tf-` tag cannot pass the gate:

1. Enable GitHub Actions for the repository.
2. Register the self-hosted runner and set `IOS_RUNNER=self-hosted`,
   `IOS_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
   (`Tooling/docs/ci.md`, "Self-hosted runner on this Mac").
3. In App Store Connect, create one Xcode Cloud workflow started by the
   `testflight` branch, with archive distribution **TestFlight and App Store**.

## Risk

The manual build was uploaded as version `1.0`. If App Store Connect treats
`1.0.0` as the same version, Xcode Cloud's build numbers must stay above
202609211; set the workflow's next build number accordingly before the first
round.
