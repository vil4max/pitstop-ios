# Task — RD-012 Car profile (Agentic SDLC pilot round)

Assignee: Pitstop (local_1b8d76c5-4a66-436c-9d0f-8e59157a2252), host Claude desktop
State: claimed
Requested by: SDLC Orchestrator relaying owner request (2026-09-24)
Evidence: pending
Depends-on: kit-alignment
Parallelism: none
Profile: round
Plan hash: 633e53470a50acf45215ceab92ed8c21183b6a25346b92f4f1009ce4789cfb09

## Current status and authorization

Current outcome: cards `car-profile-data` (`5a76746`), `car-visual`
(`43e9d47`) and `car-editor-profile` (`0a2f7db`, two repairs, round 3
clean) landed; card `car-avatar` dispatched.
Authorized scope: the owner in this session on 2026-09-24: "RD-012 делаем как
pilot round по новому SDLC flow: в старом brief не начинай, оркестратор
пришлёт задачу, открой её в plan mode."; the RD-012 pilot plan approved
through ExitPlanMode (Part B: opening, four cards, close, ship); release
scope "1.2.0 after RD-012 (Recommended)". The pilot-minimum package was
approved by the owner on 2026-09-24 ("да", kit `docs/tasks/ios-sdlc-review.md`).
Package approval, owner in this session on 2026-09-24, through
`AskUserQuestion` with named options ("Approve the package" / "Approve
without the avatar" / "Not yet"); question: "Approve the RD-012 package as
one decision? It covers: REQ-BOARD-032 (first launch never asks for a
photo), REQ-BOARD-033 (removing the photo removes its files), REQ-BOARD-034
(car avatar 28 pt in headers, 44 pt in Pit, not in Settings, forms or
lists); ADR 0040 (photo files in the App Group, only an id in schema V5,
Vision lift on device with whole-photo fallback, the unused DefaultVehicleHero
image deleted); four cards: car-profile-data, car-visual,
car-editor-profile, car-avatar, writers on opus. Plan hash
633e5347…cfb09."; answer, verbatim: "Approve the package".
Blocking decisions: none.
Permitted deviations: none.
Material assumptions: the simulator's Vision may return no foreground
instance, so the lifted path is checked on a device (What to Test); checked
at card `car-visual` by running the fake and the Vision path in tests.
Next step: integrate card `car-avatar` after repair 1 and its round 2 review; then close the round.
Requirements: REQ-BOARD-017, REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-031,
REQ-BOARD-032, REQ-BOARD-033, REQ-BOARD-034, REQ-DESIGN-005
Acceptance specs: tests citing each requirement above in their display name,
passing in a fresh `just ci` result bundle (the coverage matrix).
Owned files: per card, in its dispatch record.
Out of scope: iOS 27.1 API; a Runtime or toolchain change; a snapshot-testing
dependency; a camera entry; the avatar in widgets; SYS-008 layouts; parked
kit features; XcodeBuildMCP and xcode-tools (disabled for pitstop-ios).
Failure conditions: a screen loses behaviour or an existing test changes
meaning; a colour literal or `glassEffect` outside `DesignSystem/` reaches a
commit; a real photo, VIN, plate or personal detail enters the public
repository; the photo reaches analytics, logs, the network, a widget
timeline entry or the store as bytes; a shipped store (V1, V2, V4) fails to
open under V5; anything reaches `main` without the owner's word in this
session.

## Scope

RD-012 replaces the abstract car with the owner's car. The car editor gains
an optional photo from the photo library (`PhotosPicker`, no camera) and a
body choice (SUV or sedan, SUV by default). The photo is lifted onto the
stage on device, or shown whole under the stage mask when the lift fails;
without a photo the car is the neutral side-view placeholder for the chosen
body, facing right. The same picture replaces `AbstractCarView` on the Car
Board stage, the Car Board tiles and the Road lane, and a round car avatar
appears in detail screen headers and in the Pit sheet's saved state and
question card. The store moves to schema V5 (body and photo id); V4 is
frozen. Decisions: ADR 0040.

Not in scope: the avatar in widgets, a camera entry, make/model imagery,
iPhone Duo layouts (SYS-008), iOS 27.1 API.

## Acceptance

- REQ-BOARD-017: Car Board shows the car visual in the hero and the display
  name as the screen title, and no technical specification list.
- REQ-BOARD-029: a picked photo is stored as files in the App Group
  container, shown on the stage, and never sent to analytics, logs or any
  network, nor placed in a widget timeline entry.
- REQ-BOARD-030: without a photo the placeholder is the body the owner chose,
  SUV when none was chosen, never derived from other data.
- REQ-BOARD-031: a photo whose subject cannot be lifted is shown whole under
  the stage mask, with no error.
- REQ-BOARD-032: first launch never asks for a photo and shows the SUV
  placeholder.
- REQ-BOARD-033: removing the photo deletes all its files and the store's
  reference, and shows the placeholder for the chosen body.
- REQ-BOARD-034: the avatar is 28 pt in detail headers and 44 pt in the Pit
  sheet's saved state and question card, hidden from VoiceOver, and absent
  from Settings, forms and list rows.
- REQ-DESIGN-005: with no photo, every surface shows the placeholder for the
  chosen body, facing right, never a make, model or body from other data.
- Every shipped store (V1, V2, V4) and V3 opens under V5 with its data
  intact.
- `spec_trace.py matrix` exits 0 on a fresh `just ci` bundle; device-only
  checks are Deferred rows approved by the owner.

## Constraints

- On device only: the photo, its files and the lift never leave the iPhone;
  JPEG re-encode drops metadata (ADR 0040).
- iOS 27.0 SDK, stable Xcode 27.0 toolchain, no new dependency.
- Colour through design-system roles only; glass only inside
  `DesignSystem/` (REQ-DESIGN-002, REQ-DESIGN-004).
- Shipped schemas stay frozen; migrations are lightweight.
- Writers do not use the simulator; the integrator takes screenshots on the
  Runtime's iPhone 17 from this checkout after each fast-forward.
- Public repository: fictional data only in tests and previews.

## Cards

#### Card: car-profile-data — Body, photo id and photo files under schema V5

model: opus
product question: n/a — no user-facing change; the data layer the other cards build on
metric: n/a — no user-facing change
threshold: n/a — no user-facing change
user-visible: none

Requirements: REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-033

#### Card: car-visual — The car as the owner's photo or the chosen body

model: opus
product question: Does the owner see a car that reads as theirs instead of an abstract shape?
metric: What to Test item "Car on the stage, tiles and Road" on the 1.2.0 build
threshold: PASS on the owner's device check
user-visible: The car on Car Board and Road is now a side-view SUV or sedan facing right, or your own photo.

Requirements: REQ-BOARD-017, REQ-BOARD-030, REQ-BOARD-031, REQ-DESIGN-005

#### Card: car-editor-profile — Photo and body in the car editor

model: opus
product question: Can the owner give the car its own photo and body without an error or a permission prompt?
metric: What to Test item "Choose and remove a car photo" on the 1.2.0 build
threshold: PASS on the owner's device check, lifted or shown whole
user-visible: Choose a photo of your car and its body (SUV or sedan) in the car editor, or remove the photo.

Requirements: REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-032, REQ-BOARD-033

#### Card: car-avatar — The car avatar in headers and in Pit

model: opus
product question: Does the avatar tell the owner which car a screen is about without crowding the header?
metric: What to Test item "Car avatar" on the 1.2.0 build, at the default and largest text size
threshold: PASS on the owner's device check
user-visible: Your car's avatar now appears in screen headers and in Pit.

Requirements: REQ-BOARD-034

## Dispatches

Common to every dispatch: base is the brief commit that records it; one
`slice-writer` in its own worktree; the writer runs `just verify` per step,
never the simulator; failing REQ-tagged tests first (display name starts
with the REQ ID); one Writer step per commit under the kit commit policy;
light, dark and AX-XL previews for any view; the report ends with
`Conflicts found`. Boundaries also cover the target-membership line in
`Pitstop.xcodeproj/project.xcproj` when a new file joins a layer the app and
the widget share (added after car-profile-data).

### car-profile-data dispatch — Body, photo id and photo files (2026-09-24)

Objective: Add the car's body choice and photo id to the domain and to a new
schema V5, freeze V4, and add a file store for car photos in the App Group
container, with migration tests from every earlier version.

Sources: REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-033; ADR 0040 "Storage",
"Body", "Schema"; ADR 0007 (frozen versions); ADR 0036 (App Group location).

Intended deviations: none

Boundaries: owned `Pitstop/Domain/Vehicle/`, `Pitstop/Infrastructure/Persistence/`,
new `Pitstop/Infrastructure/CarPhoto/`, `Shared/` only if the store location
helper lives there, and matching tests under `PitstopTests/`. Corrected by the
integrator during the run (dispatch errors, not deviations from a Source):
`Pitstop/Domain/Capture/DomainCommands.swift` for the new command cases and
their `validate` branch only (the dispatch named `Domain/Store/`, where
`DomainCommand` does not live), and one line in
`Pitstop.xcodeproj/project.xcproj` adding `PitstopSchemaV5.swift` to the
widget target's membership list. Do not touch
views, the car editor or `AbstractCarView`. Stop and report if V5 cannot be a
lightweight stage or a V1/V2/V4 store fails to open.

Output: the writer report (READY or BLOCKED, steps with SHAs, gate results,
`Conflicts found`), filed under
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-profile-data/`.

### car-visual dispatch — CarVisual replaces AbstractCarView (2026-09-24)

Objective: Add the design-system `CarVisual` (lifted photo, whole photo under
the stage mask, placeholder for the body facing right) and a subject-lift
service behind a protocol with a Vision implementation and a fake; replace
`AbstractCarView` on the Car Board hero, the tiles and the Road lane; delete
`AbstractCarView` and the unused `DefaultVehicleHero` image.

Sources: REQ-BOARD-017, REQ-BOARD-030, REQ-BOARD-031, REQ-DESIGN-005,
REQ-BOARD-024 (label); ADR 0040 "Lift", "Placeholders", "One component";
mockup: `docs/design/ios27-mockups.html` Car profile frames (stage and Road
"Now").

Intended deviations: none

Boundaries: owned `Pitstop/DesignSystem/Components/` (new `CarVisual`, remove
`AbstractCarShape.swift`), `Pitstop/Assets.xcassets` (placeholders in,
`DefaultVehicleHero` out), new `Pitstop/Infrastructure/SubjectLift/`,
`Pitstop/Features/CarBoard/CarHeroView.swift`,
`Pitstop/Features/CarBoard/CarBoardTileView.swift`,
`Pitstop/Features/Road/RoadLaneView.swift`, and matching tests. Corrected
by the integrator during the run (wiring only, a dispatch error, not a
deviation): `Pitstop/Features/CarBoard/CarBoardView.swift`,
`Pitstop/Features/Road/RoadView.swift`, `Pitstop/App/RootView.swift` (the
`RoadView` call) and `Pitstop/App/AppCoordinator.swift` (an optional
`CarPhotoStore` from the group container). Do not touch
the car editor or headers. Stop if a placeholder cannot render through a
colour role. Build on card car-profile-data's API: `CarPhotoStore`
(`save(original:lifted:)` → `CarPhotoID`, `files(for:)`, `delete(_:)`) and
the car's `body` / photo id. The lifter's input is the stored original,
already bounded to 2048 px, never the picked full-resolution data (round 1
review, `CarPhotoStore.swift:53`). Test images are synthesized in code; no
photo file enters the repository.

Output: the writer report, filed under
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-visual/`.

### car-editor-profile dispatch — Photo and body in the car editor (2026-09-24)

Objective: Give the car editor a Photo row (`PhotosPicker`, "Choose photo",
"Remove photo", footer "Stays on this iPhone…"), a Body control (SUV,
Sedan), then Name and Mileage; on save, store or remove the photo files
through the photo store and the lift, and save the body.

Sources: REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-032, REQ-BOARD-033; ADR 0040
"Picking", "Privacy"; mockup: `docs/design/ios27-mockups.html` car editor
frame.

Intended deviations: none

Order on save (round 1 review, `CarProfileCommands.swift:20`): write the new
files, then run `setCarPhoto`, then delete the old id's files; if the command
fails, delete the new files; on remove, run `setCarPhoto(nil)`, then delete.
The lift runs on the bounded original (`CarPhotoStore.swift:53`).

The lifter takes a bounded image (at most 2048 px on the long side) that the
editor path makes from the picked data itself, because `CarPhotoStore.save`
does not return one (car-visual round 1 review, `SubjectLifter.swift:9`).

Boundaries: traced from the view to the composition root; owned
`Pitstop/Features/CarBoard/CarEditorView.swift`,
`Pitstop/Features/CarBoard/CarBoardView.swift` (the editor call site),
`Pitstop/Features/CarBoard/CarBoardViewModel.swift`,
`Pitstop/App/AppCoordinator.swift` (compose `VisionSubjectLifter` into the
view model), a new `Pitstop/Infrastructure/CarPhoto/CarPhotoPreparation.swift`
(decode and bound the picked data), the car editor keys in
`Pitstop/Resources/Localizations/Localizable.xcstrings` (en, ru, uk), and
matching tests (including a test that the analytics payload and log cases
carry no photo data). Do not touch the store schema, `CarPhotoStore`,
`CarVisual` or `SubjectLifter` beyond calling them.

Output: the writer report, filed under
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-editor-profile/`.

### car-avatar dispatch — CarAvatar in headers and in Pit (2026-09-24)

Objective: Add the design-system `CarAvatar` (round, photo or placeholder,
28 pt and 44 pt, hidden from VoiceOver) and show it in detail screen headers
(Road, Notes, History, Service) and in the Pit sheet's saved state and
question card.

Sources: REQ-BOARD-034; ADR 0040 "One component"; mockup:
`docs/design/ios27-mockups.html` header and Pit sheet frames.

Intended deviations: none

Boundaries: traced from the car board state to each surface; owned
`Pitstop/DesignSystem/Components/` (new `CarAvatar`, and one environment
value carrying the car's body and photo files), `Pitstop/App/RootView.swift`
(set that value from the car board state), `Pitstop/DesignSystem/Components/ScreenHeader.swift`
(an optional avatar before the eyebrow), `Pitstop/Features/Shared/FeatureScaffold.swift`
(detail screens: Road, Notes, History, Service), `Pitstop/Features/Pit/PitSheetParts.swift`
(saved state), `Pitstop/Features/Pit/PitQuestionCard.swift`,
`Pitstop/Features/Pit/PitCaptureView.swift` and `Pitstop/Features/Pit/PitInSheet.swift`
(only if the value must be passed into a presented sheet), and matching tests.
Reuse `CarVisual`'s picture resolution and decoder without changing them. No
avatar on Car Board's own header, in Settings, forms, list rows or widgets.

Output: the writer report, filed under
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-avatar/`.

### car-editor-profile repair 1 dispatch — Lock while saving, surface a failed pick (2026-09-25)

Objective: Make the car editor lock Cancel and swipe while a save runs, make
a failed photo load clear the staged photo, say so in the Photo row and allow
the same item to be picked again. The low at `CarBoardViewModel.swift:159`
was dropped from this repair on the orchestrator's relay of the kit rule
(lows go to the backlog) and is in the backlog.

Sources: REQ-BOARD-029, REQ-BOARD-033; round 1 review findings
`CarEditorView.swift:70` (medium), `CarEditorView.swift:144` (medium) and
`CarBoardViewModel.swift:159` (low); ADR 0032 (locking a save sheet, as
`PlannedEventEditorView` does).

Intended deviations: none

Boundaries: the writer's own branch, rebased onto the round head first
(KIT-D-024); owned `Pitstop/Features/CarBoard/CarEditorView.swift`,
`Pitstop/Features/CarBoard/CarBoardViewModel.swift`, the car editor keys in
`Pitstop/Resources/Localizations/Localizable.xcstrings` (en, ru, uk) for one
new failed-load line, and matching tests. One commit per finding, each with a
failing test first.

Output: an updated writer report (READY or BLOCKED, the repair commits,
gate, `Conflicts found`) appended to
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-editor-profile/writer-report.md`.

### car-editor-profile repair 2 dispatch — A failed pick keeps a staged remove (2026-09-25)

Objective: A photo load that fails or returns nothing resets only a staged
replacement; a staged remove stays staged, so Save still removes the photo.

Sources: REQ-BOARD-033; round 2 review finding `CarEditorView.swift:58`
(medium, a regression from repair 1) and the round 1 finding
`CarEditorView.swift:144` it must keep closed.

Intended deviations: none

Boundaries: the writer's branch rebased onto the round head first
(KIT-D-024); owned `Pitstop/Features/CarBoard/CarEditorView.swift` and
`PitstopTests/CarBoard/CarEditorTests.swift` (correct
`failedLoadKeepsTheSavedPhoto`, which asserts the regression, and add the
remove-then-failed-pick case). One commit, failing test first. The two round
2 lows are not repaired (backlog).

Output: a Repair 2 section appended to the writer report in
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-editor-profile/writer-report.md`.

### car-avatar repair 1 dispatch — The saved-state header stacks at accessibility sizes (2026-09-25)

Objective: At accessibility text sizes, the Pit sheet's saved-state header
stacks its avatar and title the way `ScreenHeader` and `PitQuestionCard` do,
so the title keeps the full width.

Sources: REQ-BOARD-034; round 1 review finding `PitSheetParts.swift:16`
(medium); mockup: `docs/design/ios27-mockups.html` Dynamic Type rule (the
words wrap under the avatar).

Intended deviations: none

Boundaries: the writer's branch rebased onto the round head first
(KIT-D-024); owned `Pitstop/Features/Pit/PitSheetParts.swift` and its tests.
One commit, failing test first. The two round 1 lows are not repaired
(backlog).

Output: a Repair 1 section appended to the writer report in
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-avatar/writer-report.md`.

## Evidence history

- 2026-09-24: round opened; `spec_trace.py --prose` on Car Hero, Car profile
  and Car image found 7 normative sentences without an ID
  (`car-board-screen.md:163`, `:168` ×2; `product-design.md:229`, `:234`,
  `:239` ×2); the photo-in-first-launch and file-removal rules had no
  requirement and became REQ-BOARD-032 and REQ-BOARD-033; the avatar prose
  (no normative keyword, not flagged) became REQ-BOARD-034; the rest is
  covered by REQ-BOARD-029, REQ-BOARD-030 and REQ-DESIGN-005.

- 2026-09-24, card `car-profile-data`: writer READY at `5a76746`
  (`522a8f8`, `fe9bbb1`, `5a76746`), each step failing first (test build
  error, exit 65) and `just verify` green per step; Conflicts found: none;
  report in `agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-profile-data/`.
  Five existing suites now seed older stores through
  `PitstopTests/Support/LegacyStoreWriter.swift` (SwiftData cannot cast an
  older container's car row to the V5 class); the round 1 review found their
  assertions unchanged in meaning. Landed by `git merge --ff-only` onto
  `RD-012/car-profile`; worktree removed, branch deleted; `just verify` on
  `5a76746` → verify OK. No screenshots: the card changes no view.

- 2026-09-25, card `car-visual`: writer READY at `43e9d47` (`0a2af54`,
  `623ae5d`, `43e9d47`), each step failing first and `just verify` green;
  Conflicts found: the hero car stays decorative for VoiceOver as the mockup
  (`ios27-mockups.html:462`) draws it, which REQ-BOARD-024 allows, against
  ADR 0040's "keeps a label" (the ADR wording is corrected at close). The
  Vision cut-out cannot run on the simulator ("Could not create inference
  context"), so that shape test is skipped there; the other REQ-BOARD-031
  tests pass. Landed by `git merge --ff-only`; `just verify` on `43e9d47` →
  verify OK. Screenshots on the Runtime simulator (`just run-sim`, captured
  with `xcrun simctl io` because the simulator tool's device-access prompt
  went unanswered): Car Board light, dark and AX-XXXL, in
  `agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-visual/`; the SUV
  placeholder faces right on the hero and the Road tile; the dashed horizon
  shows faintly through the wheels (translucent `contentSecondary`).

- 2026-09-25, card `car-editor-profile`: writer READY at `5f853ba`
  (`b295e6c`, `5f853ba`), each step failing first and `just verify` green;
  no ownership gap (Boundaries traced along the data flow). Conflicts found,
  each settled REQ > mockup > dispatch: the rows follow the mockup (Photo,
  Name, Body, Mileage); no avatar or thumbnail in the form (REQ-BOARD-034),
  though the mockup draws one; "Stays on this iPhone…" sits in the Choose
  photo row as the mockup draws it. The writer added a partial-save message
  (`carEditor.failure.profileOnly`) and its own ru and uk wording, both for
  the owner's review. Round 1 review: 2 medium; repair 1 dispatched.
  Repair 1 READY at `e3f878b` after a clean rebase onto `4e23751` (steps
  now `070ef30`, `972b699`; repairs `ccf6654`, `e3f878b`); the round 1 low
  at `CarBoardViewModel.swift:159` was dropped from it before it started
  (lows go to the backlog). Round 2 review: 1 medium, a regression from
  repair 1; repair 2 dispatched (second of three). Repair 2 READY at
  `0a2f7db` after a clean rebase onto `f170f5b` (final SHAs: `e47d15e`,
  `0c0ce81`, `b0042a7`, `fb8ddb3`, `0a2f7db`). Round 3 review: 0
  high/medium, 2 low (backlog), no regression; the KIT-D-022 rework
  question after a third round did not arise, because the card closed
  clean. Landed by `git merge --ff-only`; `just verify` on `0a2f7db` →
  verify OK. Not checked on screen: the car editor opens only by a tap and
  the simulator tool's access prompt went unanswered; it joins the 1.2.0
  What to Test.

- 2026-09-25, card `car-avatar`: writer READY at `109a102` (`b36504d`,
  `109a102`), each step failing first and `just verify` green; Conflicts
  found: none; no ownership gap. The dispatch's `PitSheetParts.swift:195`
  pointed at a preview, so the writer put the saved-state avatar in
  `PitMomentHeader`, shown only with "Saved.", within its owned files. The
  value is set once in `RootView.content`, which both Pit presentations
  inherit. Road "Now" keeps the car picture from card `car-visual`, not an
  avatar (REQ-BOARD-034 names headers and the Pit sheet). Round 1 review:
  1 medium; repair 1 dispatched.

### Round 1 review — car-profile-data (2026-09-24)

Review SHA: 5a76746

- [low][non-blocking][new] Pitstop/Infrastructure/CarPhoto/CarPhotoStore.swift:53 — the lifted PNG is written at whatever size the caller passes; a lift of a 48 MP photo at source resolution could reach tens of MB, beyond ADR 0040's "a few megabytes per car" (carried into the car-editor-profile dispatch: lift from the bounded original)
- [low][non-blocking][new] Pitstop/Infrastructure/CarPhoto/CarPhotoStore.swift:126 — an original with an alpha channel is JPEG-encoded without flattening, so transparent areas of a picked PNG or HEIC may turn black under the stage mask (backlog at close)
- [low][non-blocking][new] Pitstop/Infrastructure/Persistence/RecordMapping.swift:30 — a stored body value this build cannot read is erased to nil by any unrelated car write; hypothetical while only `suv` and `sedan` exist (accepted)
- [low][non-blocking][new] Pitstop/Domain/Vehicle/CarProfileCommands.swift:20 — deleting the old photo's files is left to the caller, so a kill between saving files and the command leaves unreferenced files (carried into the car-editor-profile dispatch: order and clean-up)
- [low][non-blocking][new] PitstopTests/Widgets/NextServiceWidgetTests.swift:340 — the never-migrate test seeds V3; no test pins that the widget leaves the shipped V4 store untouched (backlog at close)

### Round 1 review — car-visual (2026-09-25)

Review SHA: 43e9d47

- [low][non-blocking][new] Pitstop/DesignSystem/Components/CarVisual.swift:138 — a cancelled decode can still write `loaded` after a newer photo's decode; with a cache clear in between the frame stays empty until the id changes (backlog at close; lows are not repaired, `defect-first-before-commit`)
- [low][non-blocking][new] Pitstop/DesignSystem/Components/CarVisual.swift:91 — the lookup and the insert are separate locks, so the hero and the Road tile decode the same file twice on first appearance (backlog at close; lows are not repaired, `defect-first-before-commit`)
- [low][non-blocking][new] Pitstop/DesignSystem/Components/CarVisual.swift:45 — bitmaps of a replaced photo stay cached until the ninth insert, about 30 MB at most (backlog at close; lows are not repaired, `defect-first-before-commit`)
- [low][non-blocking][new] Pitstop/Infrastructure/SubjectLift/SubjectLifter.swift:9 — the lifter expects the bounded original, but `CarPhotoStore.save` never returns it, so the editor must bound the picked data itself (carried into the car-editor-profile dispatch)
- [low][non-blocking][new] docs/decisions/0040-car-profile.md:58 — "the hero car keeps a label" contradicts the decorative hero (corrected at close)
- [low][non-blocking][new] docs/decisions/0009-design-language.md:38 — ADR 0009 still names `AbstractCarView` and `DefaultVehicleHero` and lacks an "amended by ADR 0040" note (corrected at close)
- [low][non-blocking][new] docs/design/ios27-mockups.html:1025 — the mockup draws a soft ground shadow under the lifted car; none is drawn (backlog at close, owner design choice)

### Round 1 review — car-editor-profile (2026-09-25)

Review SHA: 5f853ba

- [medium][blocking][new] Pitstop/Features/CarBoard/CarEditorView.swift:70 — the editor's `SaveSheetScaffold` does not lock while saving, so Cancel or a swipe during a multi-second photo save closes the sheet while the save runs on: the photo the owner cancelled is stored and the old files are deleted, and a late failure alert appears the next time the editor opens (`PlannedEventEditorView`, ADR 0032, locks for this reason)
- [medium][blocking][new] Pitstop/Features/CarBoard/CarEditorView.swift:144 — when `loadTransferable` fails or returns nil, the previous draft photo silently stays staged with nothing on screen to show it; Save then stores a photo the owner replaced, or reports success when the chosen photo was not saved; picking the same item again does not retry the load
- [low][non-blocking][new] Pitstop/Features/CarBoard/CarBoardViewModel.swift:159 — the view model's photo id is refreshed only by a successful `load()`; after a replace followed by a failed reload, the next remove discards the old id and leaves the new files on disk (REQ-BOARD-033) (backlog at close; lows are not repaired, `defect-first-before-commit`)
- [low][non-blocking][new] Pitstop/Features/CarBoard/CarBoardViewModel.swift:240 — when the mileage fails after the name saved, the message does not say the body and photo were not saved either; a retry resends everything (accepted: the sheet stays open)
- [low][non-blocking][new] Pitstop/Features/CarBoard/CarEditorView.swift:42 — an undecodable pick gives only the generic save failure; the in-sheet way out is "Remove photo", which removes the saved photo too (backlog at close)

### Round 2 review — car-editor-profile (2026-09-25)

Review SHA: e3f878b

- [medium][blocking][new] Pitstop/Features/CarBoard/CarEditorView.swift:58 — a failed load resets the staged photo to "unchanged" whatever it was, so "Remove photo" followed by a pick that fails to load and Save keeps the saved photo and its files the owner removed (REQ-BOARD-033); a repair regression of round-1-correct behaviour, and `CarEditorTests.swift:143` asserts it
- [low][non-blocking][new] Pitstop/Features/CarBoard/CarEditorView.swift:114 — the load-failure line is not announced to VoiceOver, unlike `MarkDoneView` and `TrackSeveralView` (backlog at close)
- [low][non-blocking][new] PitstopTests/CarBoard/CarEditorTests.swift:56 — the lock test is tagged REQ-BOARD-029, which says nothing about locking; the matrix counts it as that requirement's coverage (backlog at close)

### Round 3 review — car-editor-profile (2026-09-25)

Review SHA: 0a2f7db

- [low][non-blocking][new] PitstopTests/CarBoard/CarEditorTests.swift:137 — the corrected test keeps the name `failedLoadKeepsTheSavedPhoto` while it now asserts the remove is kept (backlog at close)
- [low][non-blocking][new] PitstopTests/CarBoard/CarEditorTests.swift:156 — no test pins remove, then a successful pick, then a failed pick giving "unchanged" (backlog at close)

### Round 1 review — car-avatar (2026-09-25)

Review SHA: 109a102

- [medium][blocking][new] Pitstop/Features/Pit/PitSheetParts.swift:16 — `PitMomentHeader` puts the 44 pt avatar beside the 44 pt head and the title in a plain row with no accessibility-size switch, unlike `ScreenHeader` and `PitQuestionCard`; at AX5 on an iPhone 17 the title loses about 56 pt of width and "Сохранено." / "Збережено." likely break inside the word
- [low][non-blocking][new] Pitstop/App/RootView.swift:95 — reading the car's body and photo in `RootView.body` re-evaluates the root modifier chain on every field write in `CarBoardViewModel.load()`; extra body work only (backlog at close)
- [low][non-blocking][new] PitstopTests/DesignSystem/CarAvatarPlacementTests.swift:131 — `carBoardHeaderHasNone` reads only the first line of the `ScreenHeader(` call, so an avatar argument on a later line would pass (backlog at close)

## Untested scope

- The lifted path on real photos (Neural Engine) and `PhotosPicker` with the
  owner's library: device checks in the 1.2.0 What to Test.

## Writer steps

Card `car-profile-data` (dispatched 2026-09-24):

- [x] Domain `CarBody` (`suv`, `sedan`) and the car's optional body and photo id, a car without a body reading as SUV and never derived from its name or make, plus `DomainCommand` cases that set or clear them: REQ-BOARD-030 tests fail first, then `just verify` — 522a8f8
- [x] `PitstopSchemaV5` with its own car record (+ body, + photo id), a lightweight V4 → V5 stage, the app and the widget reader opening V5, V4 frozen with a shape test, the store mapping and every `CarMemoryStore` implementation reading and writing body and photo id: migration tests from V1, V2, V3 and V4 stores with data intact and a round-trip test fail first, then `just verify` — fe9bbb1
- [x] `CarPhotoStore` in `Pitstop/Infrastructure/CarPhoto/`: saves the original re-encoded as JPEG (at most 2048 px on the long side, no EXIF or location metadata) and an optional lifted PNG under `CarPhotos/` in an injected container directory, returns their URLs by id, and deletes every file of an id: REQ-BOARD-029 and REQ-BOARD-033 tests fail first, then `just verify` — 5a76746

Card `car-visual` (dispatched 2026-09-24):

- [x] The owner's SUV and sedan placeholders in the asset catalog and a design-system `CarVisual` that resolves the fallback order (lifted photo, whole photo under the stage mask, placeholder for the body facing right, drawn through a colour role) with a label for the hero, previews in light, dark and AX-XL: REQ-DESIGN-005, REQ-BOARD-030 and REQ-BOARD-031 resolution tests fail first, then `just verify` — 0a2af54
- [x] A `SubjectLifter` protocol with a Vision implementation (`GenerateForegroundInstanceMaskRequest`, all instances, on device, off the main actor, returning nothing when no subject is found) and a fake: REQ-BOARD-031 tests on synthetic images fail first, then `just verify` — 623ae5d
- [x] `CarVisual` replaces `AbstractCarView` on the Car Board hero, the tiles and the Road lane, fed by the car's body and photo files; `AbstractCarView` and the unused `DefaultVehicleHero` image are deleted: REQ-BOARD-017 and REQ-DESIGN-005 tests fail first, then `just verify` — 43e9d47

Card `car-editor-profile` (dispatched 2026-09-25):

- [x] The save path: bound the picked data, lift it, store the files, then set the photo and the body, deleting the old photo's files after the command and the new files when the command fails; removing runs the command, then deletes; the view model and the composition root carry the lifter: REQ-BOARD-029, REQ-BOARD-030 and REQ-BOARD-033 tests (including no photo data in analytics or log cases) fail first, then `just verify` — e47d15e
- [x] The car editor: a Photo row (`PhotosPicker`, "Choose photo", "Remove photo", footer "Stays on this iPhone…"), a Body control (SUV, Sedan), then Name and Mileage, in en, ru and uk, with light, dark and AX-XL previews; first launch asks for no photo: REQ-BOARD-032 and REQ-BOARD-030 tests fail first, then `just verify` — 0c0ce81
- [x] Repair 1: the editor locks Cancel and swipe while a save runs: a failing test for the locked sheet first, then `just verify` — b0042a7
- [x] Repair 1: a failed photo load clears the staged photo, says so in the Photo row and lets the same item be picked again: failing tests first, then `just verify` — fb8ddb3
- [x] Repair 2: a failed photo load resets only a staged replacement and keeps a staged remove: a REQ-BOARD-033 test fails first, then `just verify` — 0a2f7db

Card `car-avatar` (dispatched 2026-09-25):

- [ ] A design-system `CarAvatar` (round, the photo or the placeholder for the body, 28 pt and 44 pt, hidden from VoiceOver) and one environment value carrying the car's body and photo files, with light, dark and AX-XL previews: REQ-BOARD-034 tests fail first, then `just verify`
- [ ] `RootView` sets the value; detail screen headers (Road, Notes, History, Service) show the 28 pt avatar before the eyebrow, and the Pit sheet's saved state and question card show the 44 pt one; Car Board's header, Settings and forms show none: REQ-BOARD-034 tests fail first, then `just verify`
- [ ] Repair 1: the saved-state header stacks its avatar and title at accessibility sizes: a REQ-BOARD-034 test fails first, then `just verify`

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|

## Coverage matrix

Generated at close by `spec_trace.py matrix`.

## Current checklist

- [ ] package approval recorded, Plan hash set, lock written
- [ ] four cards landed with review and `just verify`
- [ ] matrix exit 0, Deferred approved, `[unreleased]` lines, `State: done`
