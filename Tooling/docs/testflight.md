# TestFlight — tag-gated builds

One model for every app on this Runtime, adopted 2026-09-21 from Drive Check,
where it replaced promotion on every green push.

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
builds of one version, and OneCart could not push a tooling-only commit without
spending one. After the switch Drive Check avoided about 25 builds in 50 commits
against one tag.

## Who tags

- `tf-` tag: the owner or an agent. An agent creates and pushes it only after
  `just tf-check` prints `Ready`, on a commit that is already on `origin/main`
  (owner decision, 2026-09-21).
- `v` tag and the App Review submission: the owner only.

## Round procedure

1. The release-prep commit (version bump, notes) is the **head of its own push**
   to `main`. GitHub runs a push only for its head commit; a commit in the middle
   of a multi-commit push never gets a tests run of its own and can never be
   tagged.
2. Wait for that commit's tests run, then `just tf-check`. It is read-only and
   blocks on anything the workflow would reject, including an unknown tests
   state (no `gh`).
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

One format in every app (owner rule): `MARKETING_VERSION` is always
`MAJOR.MINOR.PATCH` — three integers, not decimals (`2.9.0` → `2.10.0`), the
same in every target and configuration. A feature release raises `MINOR` and
resets `PATCH` to 0; a fix-only release raises `PATCH`; `MAJOR` changes only when
the owner asks. Tags repeat the version (`tf-1.0.0-1`, `v1.0.0`), and
`just tf-check` blocks any other form, because the workflow would reject the tag.

App Store Connect normalizes versions: `1.0` and `1.0.0` are one version, listed
under "Version 1.0", and TestFlight offers the highest build number within it.
An app moving from a two-part to a three-part version therefore does not start a
new version by padding it: pitstop's first Xcode Cloud build 1.0.0 (2) sat below
a hand-uploaded 1.0 (202609211), and testers kept getting the old build; OneCart
saw an old 1.4 (82) above 1.3.0. When earlier uploads exist, raise the version
past them (pitstop: next round 1.1.0, OneCart went to 1.5.0), or expire the old
build and keep Xcode Cloud's numbers above its build number.

## Project format

Xcode 27.2 can store a project as JSON in `project.xcproj` instead of the
property list `project.pbxproj` ([Xcode 27.2 release
notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes),
"Project Format"; earlier Xcode 27 versions open it). tf-check, tf-promote, the
baseline and `ci_post_clone.sh` read either format through
`scripts/project_versions.py`; in JSON a per-configuration value is a key with a
condition suffix (`"MARKETING_VERSION[config=Release]"`). The file is not
strict JSON: Xcode writes a comma after every last element, so read it with the
Runtime helper, not a strict JSON parser. Convert an app only after its
`Tooling/` has this Runtime; an older Runtime finds no project file and blocks
every tag.

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

For an Xcode Cloud build, Xcode Cloud's number wins: the app's
`ci_scripts/ci_post_clone.sh` sets `CURRENT_PROJECT_VERSION` from
`CI_BUILD_NUMBER` (OneCart does this), so a TestFlight round needs no build
number commit. The owner's versioning rule — reset to 1 for a new
`MARKETING_VERSION`, higher within one — still governs the committed value,
which only a manual local archive uses. Without that script, Xcode Cloud's own
numbering and a hand-bumped value can disagree; Drive Check bumped by hand while
its release document said to keep 1. Pick the script, not both practices.

## Adopting it in an app

The TestFlight workflow is one part of the shared pipeline; adopt both together:
[ci.md](ci.md).


1. `just harness-update` installs `Tooling/scripts/tf-check.sh`,
   `tf-promote.sh`, `testflight-lib.sh` and
   `Tooling/templates/github/testflight.yml`.
2. Copy the template to `.github/workflows/testflight.yml`; set
   `TF_TESTS_WORKFLOW` if the tests workflow file is not `tests.yml`. With more
   than one tracked `.xcodeproj`, set `TF_PBXPROJ` (the path of its
   `project.pbxproj` or `project.xcproj`).
3. Remove any job that moves `testflight` on a push to `main`, and any workflow
   that moves a `release` branch on a `v` tag — one Xcode Cloud workflow, started
   by `testflight`, builds for TestFlight and for App Review.
4. Make the tests workflow's concurrency keep one run per pushed commit on `main`
   (`group: tests-${{ github.event_name == 'push' && github.sha || github.ref }}`,
   `cancel-in-progress` only for pull requests); otherwise a later push cancels
   the run a tag depends on.
5. In App Store Connect, the owner points the Xcode Cloud workflow at the
   `testflight` branch only and retires workflows started by other branches.
   Before retiring a release-branch workflow, set the remaining workflow's
   archive distribution to **TestFlight and App Store**: with "TestFlight
   (Internal Testing Only)" no build of the model could be submitted to App
   Review ([Apple: Creating a workflow that builds your app for
   distribution](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution)).
   The App Store Connect web editor labels that option **App Store Connect**
   ("Eligible for distribution to all testers and customers"); the other
   choices are None and TestFlight (Internal Testing Only). Found while
   configuring OneCart, 2026-09-21.
6. Record the change as an ADR in the app and state the tag authority in its
   `AGENTS.md`.

Contract: `tests/testflight-contract.sh`.
