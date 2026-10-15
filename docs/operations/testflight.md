# TestFlight — tag-gated builds

The release model of this app ([ADR 0013](../decisions/0013-shared-ci-and-tag-gated-testflight.md)),
adopted 2026-09-21 from Drive Check, where it replaced promotion on every green
push. The CI it relies on is described in [ci.md](ci.md).

## How a build is requested

| Event | Effect |
|---|---|
| Push to `main` | GitHub Actions runs the tests. **No build.** |
| Annotated tag `tf-MAJOR.MINOR.PATCH-BUILD` on a verified commit | `testflight.yml` fast-forwards the `testflight` branch; Xcode Cloud archives it for internal TestFlight |
| Annotated tag `vMAJOR.MINOR.PATCH` | Nothing moves. The workflow checks that it marks a commit whose own `tf-` round exists — the build submitted to App Review |

A `tf-` tag is accepted only when the tagged commit is on `main`, every
`MARKETING_VERSION` in the project equals the tag's version, and the commit has
its **own** successful tests run for a push to `main`. Containment in a green
branch is not enough: a red commit followed by a green one is contained too.

Why tags and not pushes: every build spends Xcode Cloud compute and an App Store
Connect upload slot. Under promotion on every push, documentation and tooling
commits were builds; Drive Check hit the upload cap (ITMS-90382) at about 100
builds of one version. After the switch Drive Check avoided about 25 builds in
50 commits against one tag.

## Scripts

| Script | Where it runs | Role |
|---|---|---|
| `ci_scripts/tf-check.sh [<commit-ish>]` | Locally, read-only | The release preflight: runs the workflow's own checks first and prints `Ready` with the exact tag, or the lines that block it |
| `ci_scripts/tf-promote.sh <tag>` | `testflight.yml` on a GitHub-hosted Linux runner | Checks a `tf-` tag and moves `testflight`, or checks a `v` marker |
| `ci_scripts/testflight-lib.sh`, `ci_scripts/project_versions.py` | Sourced by both | Shared checks; `MARKETING_VERSION` from either project format |
| `ci_scripts/ci_post_clone.sh` | Xcode Cloud, after cloning | Build number from `CI_BUILD_NUMBER`; trusts SwiftPM plugins and macros |

Xcode Cloud runs only the scripts with its reserved names
(`ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`), so the
TestFlight scripts next to `ci_post_clone.sh` change nothing in its build.
Locally `tf-check.sh` needs `git`, `python3` and a signed-in `gh`; without `gh`
the tests state is unknown, and unknown blocks.

## Who tags

- `tf-` tag: the owner or an agent. An agent creates and pushes it only after
  `ci_scripts/tf-check.sh` prints `Ready`, on a commit that is already on
  `origin/main` (owner decision, 2026-09-21).
- `v` tag and the App Review submission: the owner only.

## Round procedure

1. The release-prep commit (version bump, notes) passes `ios-verify` (or
   `scripts/release-check.sh`, which also demands a clean tree) and is the
   **head of its own push** to `main`. GitHub runs a push only for its head
   commit; a commit in the middle of a multi-commit push never gets a tests run
   of its own and can never be tagged.
2. Wait for that commit's tests run, then `ci_scripts/tf-check.sh`. It is
   read-only and blocks on anything the workflow would reject, including an
   unknown tests state (no `gh`).
3. Write the annotation — this round's What to Test: a checklist of observable
   pass/fail behavior plus what was not verified.
4. Run the two commands it prints (`git tag -a -F <file> tf-… <sha>`, then
   `git push origin tf-…`). The next free BUILD comes from the remote's tags.
5. The workflow waits for a still-running tests run, then moves `testflight`.
   Paste the annotation into App Store Connect when the build appears.

A tag on a commit `testflight` already contains starts nothing; rebuild with
Start Build on `testflight` in App Store Connect instead.

Tag the next round only after the previous Xcode Cloud build has uploaded: a new
`testflight` move can make the workflow cancel a build still running (OneCart
waited for 1.5.0 (113) before tagging `tf-1.5.0-2`).

## Versions

One format (owner rule): `MARKETING_VERSION` is always `MAJOR.MINOR.PATCH` —
three integers, not decimals (`2.9.0` → `2.10.0`), the same in every target and
configuration. A feature release raises `MINOR` and resets `PATCH` to 0; a
fix-only release raises `PATCH`; `MAJOR` changes only when the owner asks. Tags
repeat the version (`tf-1.0.0-1`, `v1.0.0`), and `tf-check.sh` blocks any other
form, because the workflow would reject the tag.

App Store Connect normalizes versions: `1.0` and `1.0.0` are one version, listed
under "Version 1.0", and TestFlight offers the highest build number within it.
An app moving from a two-part to a three-part version therefore does not start a
new version by padding it: pitstop's first Xcode Cloud build 1.0.0 (2) sat below
a hand-uploaded 1.0 (202609211), and testers kept getting the old build. When
earlier uploads exist, raise the version past them (pitstop: next round 1.1.0),
or expire the old build and keep Xcode Cloud's numbers above its build number.

## Project format

Xcode 27.2 can store a project as JSON in `project.xcproj` instead of the
property list `project.pbxproj` ([Xcode 27.2 release
notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes),
"Project Format"; earlier Xcode 27 versions open it). `tf-check.sh`,
`tf-promote.sh` and `ci_post_clone.sh` read either format; the first two go
through `ci_scripts/project_versions.py`. In JSON a per-configuration value is a
key with a condition suffix (`"MARKETING_VERSION[config=Release]"`). The file is
not strict JSON: Xcode writes a comma after every last element, so read it with
that helper, not a strict JSON parser.

Convert with Xcode 27.2 (the file inspector's Project Format pop-up, or from the
command line):

```bash
DEVELOPER_DIR=<Xcode 27.2>/Contents/Developer xcodebuild -project App.xcodeproj -convert-project "Xcode Project"
```

`json` is not an accepted format name; "Xcode Project" is the JSON format, and
an Xcode version name ("Xcode 27.0") writes a property list. Checked on pitstop
in a scratch copy (2026-09-21): Xcode 27.0's `xcodebuild` lists and builds the
converted project, and `ci_post_clone.sh` sets its build number, which 27.0
then reports.

## Build numbers

For an Xcode Cloud build, Xcode Cloud's number wins: `ci_scripts/ci_post_clone.sh`
sets `CURRENT_PROJECT_VERSION` from `CI_BUILD_NUMBER`, so a TestFlight round
needs no build number commit. The owner's versioning rule — reset to 1 for a new
`MARKETING_VERSION`, higher within one — still governs the committed value,
which only a manual local archive uses. Without that script, Xcode Cloud's own
numbering and a hand-bumped value can disagree; pick the script, not both
practices.

`ci_post_clone.sh` searches `$CI_PRIMARY_REPOSITORY_PATH`, not `.`: Xcode Cloud
runs custom scripts from the `ci_scripts` directory (Apple, "Writing custom build
scripts"), where `find .` sees no project file and the rewrite silently does
nothing (found in OneCart on 2026-09-21).

## Xcode Cloud workflow (owner, App Store Connect)

One workflow, per Apple's [Creating a workflow that builds your app for
distribution](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution):

- General: restrict editing — required for a build eligible for App Review;
- Environment: Clean;
- start condition: branch changes on `testflight` only;
- action: Archive — iOS, distribution **TestFlight and App Store** (the web
  editor labels it **App Store Connect**, "Eligible for distribution to all
  testers and customers"), not "TestFlight (Internal Testing Only)": in this
  model the build submitted to App Review is a TestFlight round's build;
- no test action: GitHub Actions ran the tests for that exact commit;
- post-action: TestFlight internal testing with a group that includes the owner.
