# CI

Continuous integration of this app ([ADR 0013](../decisions/0013-shared-ci-and-tag-gated-testflight.md)):
GitHub Actions tests every push to `main`, and Xcode Cloud builds for TestFlight
only from a `tf-` tag ([testflight.md](testflight.md)). CI calls Apple's tools
and SwiftLint directly; the local gate is `ios-verify` of the ios-dev plugin,
configured by [`ios-verify.conf`](../../ios-verify.conf).

## Pieces

| Piece | Role |
|---|---|
| `.github/workflows/tests.yml` | On a push to `main` and on pull requests, on a macOS runner: `swift-format lint --strict` and `swiftlint lint --strict` on every tracked Swift file with the committed `.swift-format` and `.swiftlint.yml`, then `xcodebuild test` with a result bundle at `build/ci/results/tests.xcresult`; coverage in the job summary; `build/ci` uploaded as `ci-output` |
| `.github/workflows/testflight.yml` | On a `tf-` or `v` tag: `ci_scripts/tf-promote.sh` ([testflight.md](testflight.md)) |
| `ci_scripts/ci_post_clone.sh` (next to the `.xcodeproj`) | In Xcode Cloud: build number from `CI_BUILD_NUMBER`; trust SwiftPM plugins and macros |
| `.github/rulesets/*.json` | The repository rulesets (below) |
| Xcode Cloud workflow | App Store Connect, owner: one workflow, started by the `testflight` branch only, archives for TestFlight |

The test run builds in Debug, signs ad hoc (`CODE_SIGN_IDENTITY=-`, which keeps
Keychain access for the test host), collects coverage and turns parallel testing
off (simulator clones on a shared runner are the most common source of flaky
failures). It skips package plugin and macro validation, which a runner cannot
answer.

## Repository variables

| Variable | Default | Set it when |
|---|---|---|
| `IOS_RUNNER` | `xcode-27` (GitHub-hosted) for a public repository, `self-hosted` for a private one | A runner needs another label. A private repository never defaults to hosted macOS, which GitHub Free bills at ten times the Linux rate; without a registered runner its job waits instead of spending minutes |
| `IOS_DEVELOPER_DIR` | `/Applications/Xcode_27.0.app/Contents/Developer` | The runner's Xcode lives elsewhere (self-hosted: `/Applications/Xcode.app/Contents/Developer`) |
| `IOS_PROJECT`, `IOS_SCHEME` | `Pitstop.xcodeproj`, `Pitstop` | The project or scheme is renamed |
| `IOS_DESTINATION` | `platform=iOS Simulator,name=iPhone 17,OS=27.0` | The runner image lacks that simulator or runtime |

## Repository settings

- **Public, clean history.** `AGENTS.md` declares the repository public, which
  turns on the pre-push private-data scan.
- **Rulesets:** the three files in `.github/rulesets/`, active and without bypass
  actors:

  ```bash
  for r in delivery-branches release-tags testflight-tags; do
    gh api -X POST repos/<owner>/<repo>/rulesets --input ".github/rulesets/$r.json"
  done
  ```

  `main` and `testflight` cannot be deleted or rewritten; a `v` tag cannot be
  moved or deleted, since it records what was submitted. A `tf-` tag cannot be
  moved but can be deleted: a tag the workflow rejected is deleted and a fixed
  commit tagged with the next BUILD, and a deletion rule would leave no one able
  to do that. There is no required status check and no pull-request rule: both
  would block the direct pushes to `main` that the tag model relies on, and
  `tf-check.sh` already requires the tagged commit's own green run.
- **Xcode Cloud access:** the Xcode Cloud GitHub app is granted per repository,
  not per name. A new repository, even under an old name, is added under the
  GitHub app's repository access before its workflow can build, and the
  workflow is re-bound to it (Xcode Cloud → Settings → Repositories → Change
  URL) before the first `tf-` tag.

## Git hooks: no builds on push

A git push hook builds nothing and starts no simulator (owner decision,
2026-09-29). Builds and tests run in `ios-verify` locally and in the `Tests`
workflow. Why: a pre-push hook that ran smoke tests on a simulator blocked a
push on a Mac without a simulator runtime, and tested whatever was on disk,
including another session's unfinished edits.
