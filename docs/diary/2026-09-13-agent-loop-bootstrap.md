# PitStop agent development loop bootstrap

## Question

Can PitStop support a repeatable task → implementation → deterministic
verification → independent review loop with evidence suitable for a technical
interview?

## Scope and ownership

The owner requested local agent-loop setup. Product features remain frozen
under the infrastructure exception in `PROJECT_STATUS.md`. No model provider,
product feature, release, application submission, or career publication was
part of this change.

Base commit: `2032a7923591e32919dea115573d95675dd58e6f`.
The pre-existing edit to `specs/40_AI_ENGINEERING_ROADMAP.md` was preserved and
excluded from the independent review scope.

Codex coordinated setup, ran the repository's existing Kit installer, edited
project configuration and workflow docs, and performed verification. Shared
Brain and Runtime source repositories were not changed. The owner retained
scope and publication decisions.

## Configuration

- Installed Runtime identity:
  `56ea269ed660e433a3dcd57bb1b07736dba91335ca0d012d16f713f094819184`.
- Project Entry and Runtime readiness: `READY`.
- Local tools: Xcode 26.6 (`17F113`), Swift 6.3.3, SwiftFormat 0.62.1,
  SwiftLint 0.65.0, just 1.57.0.
- Target: `Pitstop`, iPhone 17 simulator, iOS 26.5.
- CI configuration: `.github/workflows/verify.yml`; action commits pinned;
  `just verify-ci` uses the same installed Runtime as local development.

## Observed verification

1. `just doctor --json`: `ok: true`, selected `xcodebuild`.
2. Initial `just verify`: passed; 0 lint violations in 7 Swift files; build and
   the existing Swift Testing test passed. `xcresulttool` confirmed 1 total,
   1 passed, 0 failed, 0 skipped. The XCTest runner's separate "0 tests" line
   does not count the Swift Testing test.
3. Fresh temporary Git-indexed snapshot: `just verify-ci` passed, including
   build, 1 Swift Testing test, and `git diff --exit-code`. Its index contained
   all eight Runtime backend executors.

The temporary snapshot tree was
`484895d6bb0860ce2cb6608eb268320df73d7906`; Runtime fingerprint was
`de532c5a4fd27bb33bb74802aba8552047cf60d8c039db3c6161f62d896f11b4`.
It was an isolated local test snapshot, not a project commit or a remote run.
Subsequent changes removed the obsolete root formatter file, pinned action
commits, clarified milestone status, and added this evidence record. The final
working-tree gate must be rerun after those changes; the current local receipt
is managed by Runtime in the Git directory.

## Independent review

Host-native delegation created a separate read-only reviewer, `Averroes`, with
task constraints and a request to inspect the actual diff and new files.
Review identifier: `01a0987e-b3fd-7f10-add9-31551765336a`.
Result: **No findings.**

The reviewer covered Runtime provenance, executable tracking, CI failure
propagation, formatter ownership, and freeze/review/publication boundaries.
It did not run tests or independently observe a remote CI run. This diary was
written after review and records the observed outcome; it is not itself an
independently reviewed product deliverable.

## What failed or needed correction

- The repository's broad `build/` ignore rule hid Runtime shell executors.
  Added a narrow exception and verified the files in the fresh snapshot index.
- The shared scheme contained obsolete target IDs. Updated them to the IDs
  actually declared in the project file, then verified the snapshot.
- A proposed root `.swiftformat` forwarding file was rejected by a direct
  formatter check: `Unknown option --config ... in configuration file`.
  Removed that temporary approach. Canonical settings now live only in
  `Tooling/.swiftformat`; Runtime and CI pass that path explicitly.
- Xcode emitted connection warnings about a locked physical device. Simulator
  test results still passed; no device state was changed to suppress warnings.

## Deployment and environment limits

Read-only GitHub inspection found only the dynamic CodeQL workflow. The active
`Protect main` ruleset had deletion and non-fast-forward protection only.
The local `verify` workflow and proposed PR/status-check rules were not
published or applied. Artifact upload and remote runner execution are pending.
Delivery is unconfigured; `just release --check` is only a local preflight.

**EDGE CASE CANDIDATE — host setup drift:** Codex in `pitstop-ios` reports
unmanaged global policy/skills and incomplete host conformance. Kit setup also
reports an inactive-or-stale commit hook. Expected: a conformant managed host
and an active enrolled hook. Workaround: explicit project Entry points to the
current Brain and installed Runtime; CI is configured independently. Impact:
project verification works, but global hook enforcement and host snapshot
publication are not claimed. This drift was also observed earlier in this
task. Likely owner: `agent-engineering-kit` / Codex host setup. No global
snapshot or custom hook was overwritten.

## Decision and claim boundary

Adopt this bounded workflow for the next authorized PitStop task. The observed
setup demonstrates repository context, tool integration, deterministic
verification, native review delegation, and evidence-based correction.

One existing unit test is a baseline smoke check, not broad product coverage.
No productivity improvement, production AI ownership, released AI feature, or
user outcome was measured. Complete product tasks and a release/feedback loop
before expanding those claims. Runtime model evaluations belong to M4+.
