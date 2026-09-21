# CI pipeline — identical in every iOS app

One pipeline for every app on this Runtime (owner decision, 2026-09-21). The
workflow files are copied unchanged; what differs between apps is a repository
variable or the app's own `ci` recipe, never the workflow text. Why: three apps
had three pipelines (three jobs with Sonar, one job, none), so a fix found in one
never reached the others and nobody could tell which behavior was intended.

## Baseline

The apps must not drift apart (owner decision, 2026-09-21), so the shared part is
checked, not copied by hand:

- `pipeline: shared` in `Tooling/runtime.yml` makes every install and
  `just harness-update` rewrite `.github/workflows/tests.yml`, `testflight.yml`
  and `ci_scripts/ci_post_clone.sh` from the Runtime templates. A template
  change reaches every app with its next update; hand edits are overwritten.
- `just baseline` (and the start of `just verify`) fails when a managed file
  differs from its template, `simulator.name` is a machine-shared device,
  `simulator.device_type` / `simulator.os` are not `iPhone 17` / `27.0`, or
  `MARKETING_VERSION` is not one `MAJOR.MINOR.PATCH` in every configuration.
- It warns — and `just baseline --strict` fails — when the app has not opted in,
  its installed Runtime lags the Runtime checkout, its style files differ from the
  Runtime templates, or other workflows sit next to the shared ones.

Why a gate and not a checklist: within one day three apps had three pipelines,
and a workflow copied by hand went stale the next time its template changed.

## Pieces

| Piece | Source | Role |
|---|---|---|
| `.github/workflows/tests.yml` | `Tooling/templates/github/tests.yml` | On push to `main` and on pull requests: `just ci` on a macOS runner; coverage summary; `build/ci` uploaded as `ci-output`; optional Sonar job |
| `.github/workflows/testflight.yml` | `Tooling/templates/github/testflight.yml` | On a `tf-` or `v` tag: [tag-gated TestFlight](testflight.md) |
| `ci_scripts/ci_post_clone.sh` (next to the `.xcodeproj`) | `Tooling/templates/ci_post_clone.sh` | In Xcode Cloud: build number from `CI_BUILD_NUMBER`; trust SwiftPM plugins and macros |
| Xcode Cloud workflow | App Store Connect, owner | One workflow, started by the `testflight` branch only, archives for internal TestFlight |

## `just ci`

Runtime `ci.sh` runs the same gate as `just verify` and writes the test result
bundle to `build/ci/results/tests.xcresult`. With `CI=true` (GitHub sets it on
hosted and self-hosted runners):

- `just format` checks with `swiftformat --lint` and fails instead of rewriting;
- xcodebuild signs ad hoc (`CODE_SIGN_IDENTITY=-`, keeps Keychain access for
  tests); `ci.signing: none` in `Tooling/runtime.yml` disables signing instead;
- code coverage is on and parallel testing is off.

An app with more CI work overrides the recipe in its root justfile (which has
`set allow-duplicate-recipes` after `import 'Tooling/justfile'`) and calls the
Runtime first:

```just
ci:
    ./Tooling/scripts/build-slot.sh run ./Tooling/scripts/ci.sh
    ./scripts/ci-extra.sh   # another test plan, coverage conversion, …
```

Anything the Sonar job should read goes under `build/ci/`; it expects
`build/ci/sonar/coverage.xml` and an app-owned `sonar-project.properties`.

Every app runs on its own simulators, on CI and on this Mac: `<scheme> iPhone 17`
for runs and screenshots and `<scheme> iPhone 17 Tests` for tests, created on
demand (`simulator.*` keys in [api.md](api.md)); `just sim-clean` removes the
app's own leftover test clones. Set `simulator.os` (for example `"27.0"`) when the
app needs a specific iOS; unset means the newest installed runtime.

## Repository variables

| Variable | Default | Set it when |
|---|---|---|
| `IOS_RUNNER` | `xcode-27` (GitHub-hosted) for a public repository, `self-hosted` for a private one | A runner needs another label. A private repository never defaults to hosted macOS, which GitHub Free bills at ten times the Linux rate; without a registered runner its job waits instead of spending minutes |
| `IOS_DEVELOPER_DIR` | `/Applications/Xcode_27.0.app/Contents/Developer` | The runner's Xcode lives elsewhere (self-hosted: `/Applications/Xcode.app/Contents/Developer`) |
| `SONAR_ENABLED` | unset | The app reports to SonarQube Cloud (needs secret `SONAR_TOKEN`) |

## Self-hosted runner on this Mac

A private app runs its tests here. The runner's jobs go through the same
machine-wide build slots as every local session (`just build-slot status`), so a
CI run cannot overload the Mac. Security: register it only to private
repositories — a public repository would let fork pull requests run code on it.

The owner performs the registration because it needs a token from GitHub:

1. GitHub → repository → Settings → Actions → Runners → New self-hosted runner →
   macOS, ARM64. Run the shown download and `./config.sh --url … --token …`
   commands in `~/actions-runner/<repository>`; accept the default labels
   (`self-hosted`, `macOS`, `ARM64`).
2. Install it as a service so it survives logout: `./svc.sh install`, then
   `./svc.sh start`.
3. Repository → Settings → Secrets and variables → Actions → Variables:
   `IOS_DEVELOPER_DIR` = `/Applications/Xcode.app/Contents/Developer`
   (`IOS_RUNNER` is not needed: a private repository already defaults to
   `self-hosted`).

CI then runs only while the Mac is on; a queued run starts when it wakes.

## Build slots

`just build`, `test`, `verify`, `ci` and `run-sim` each hold one of `BUILD_SLOTS`
(default 2) machine-wide slots in `~/Library/Caches/ios-agent-toolchain/build-slots`
for their whole run; `just build-slot acquire <label> [minutes]` holds one for
Xcode MCP work. The directory is outside every repository on purpose: slots kept
per repository let one app's tests push the load to about 800 on 10 cores and
fail another app's gate.

## First TestFlight for a new app (owner, App Store Connect)

An app without an App Store Connect record gets one once:

1. `MARKETING_VERSION` has three components (`1.0.0`, not `1.0`): tags are
   `tf-MAJOR.MINOR.PATCH-BUILD` and tf-check compares them literally.
2. developer.apple.com → Identifiers: register the app's bundle ID (and one per
   extension, if any).
3. App Store Connect → Apps → + New App: platform iOS, name, primary language,
   that bundle ID, a SKU.
4. Xcode → Report navigator → Cloud → Create Workflow for the app (or App Store
   Connect → the app → Xcode Cloud): grant access to the GitHub repository.
5. One workflow, per Apple's "Creating a workflow that builds your app for
   distribution"
   (<https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution>):
   - General: restrict editing — required for a build eligible for App Review;
   - Environment: Clean;
   - start condition: branch changes on `testflight` only (remove the default on
     `main`);
   - action: Archive — iOS, distribution **TestFlight and App Store**, not
     "Internal Testing Only": in this model the build submitted to App Review is
     a TestFlight round's build;
   - no test action: GitHub Actions ran the tests for that exact commit;
   - post-action: TestFlight internal testing with a group that includes you.
6. First build: after the repository side is in place, `just tf-check` and a
   `tf-` tag. The Xcode Cloud run appears under the workflow; the build reaches
   TestFlight after processing.

## Adopting it in an app

1. `just harness-update`.
2. Copy both workflow templates to `.github/workflows/` unchanged; delete any
   other workflow that runs tests or moves `testflight` or `release`.
3. Copy `Tooling/templates/ci_post_clone.sh` to `ci_scripts/` next to the
   `.xcodeproj` (merge an existing one; keep only app-specific extras). Replace,
   do not keep, a script that searches with `find .`: Xcode Cloud runs custom
   scripts from the `ci_scripts` directory (Apple, "Writing custom build
   scripts"), so `find .` sees no `project.pbxproj` and the build-number
   rewrite silently does nothing. The template searches
   `$CI_PRIMARY_REPOSITORY_PATH`. Found in OneCart on 2026-09-21: its old
   script printed "Successfully updated" while leaving the number at 1;
   reproduced from a `ci_scripts` working directory with `CI_BUILD_NUMBER=106`.
4. Move app-specific CI steps into the app's `ci` recipe; delete app copies of
   Runtime scripts (`build-slot.sh`, TestFlight promotion, tf-check).
5. Set the repository variables; for a private repository, the self-hosted runner.
6. Verify: a push to `main` gives a green `Tests` run and moves nothing; then
   `just tf-check` and a `tf-` tag give one Xcode Cloud build.

Contracts: `tests/ci-contract.sh`, `tests/build-slot-contract.sh`,
`tests/testflight-contract.sh`.
