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

Current outcome: card `car-profile-data` landed (`5a76746`, review round
1: 0 high/medium, 5 low); cards `car-visual`, `car-editor-profile`,
`car-avatar` pending.
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
Next step: dispatch card `car-visual`.
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
`Pitstop/Features/Road/RoadLaneView.swift`, and matching tests. Do not touch
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

Boundaries: owned `Pitstop/Features/CarBoard/CarEditorView.swift`,
`Pitstop/Features/CarBoard/CarBoardViewModel.swift`, the en/ru/uk string
catalog entries for the editor, and matching tests (including a test that the
analytics payload and log cases carry no photo data). Do not touch the store
schema or `CarVisual` beyond calling them.

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

Boundaries: owned `Pitstop/DesignSystem/Components/` (new `CarAvatar`),
`Pitstop/Features/Shared/FeatureScaffold.swift`, the header component it
uses, `Pitstop/Features/Pit/PitSheetParts.swift`,
`Pitstop/Features/Pit/PitQuestionCard.swift`, and matching tests. No avatar in
Settings, forms, list rows or widgets.

Output: the writer report, filed under
`agent-artifacts/2026-09-24/pitstop-rd-012/outputs/car-avatar/`.

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

### Round 1 review — car-profile-data (2026-09-24)

Review SHA: 5a76746

- [low][non-blocking][new] Pitstop/Infrastructure/CarPhoto/CarPhotoStore.swift:53 — the lifted PNG is written at whatever size the caller passes; a lift of a 48 MP photo at source resolution could reach tens of MB, beyond ADR 0040's "a few megabytes per car" (carried into the car-editor-profile dispatch: lift from the bounded original)
- [low][non-blocking][new] Pitstop/Infrastructure/CarPhoto/CarPhotoStore.swift:126 — an original with an alpha channel is JPEG-encoded without flattening, so transparent areas of a picked PNG or HEIC may turn black under the stage mask (backlog at close)
- [low][non-blocking][new] Pitstop/Infrastructure/Persistence/RecordMapping.swift:30 — a stored body value this build cannot read is erased to nil by any unrelated car write; hypothetical while only `suv` and `sedan` exist (accepted)
- [low][non-blocking][new] Pitstop/Domain/Vehicle/CarProfileCommands.swift:20 — deleting the old photo's files is left to the caller, so a kill between saving files and the command leaves unreferenced files (carried into the car-editor-profile dispatch: order and clean-up)
- [low][non-blocking][new] PitstopTests/Widgets/NextServiceWidgetTests.swift:340 — the never-migrate test seeds V3; no test pins that the widget leaves the shipped V4 store untouched (backlog at close)

## Untested scope

- The lifted path on real photos (Neural Engine) and `PhotosPicker` with the
  owner's library: device checks in the 1.2.0 What to Test.

## Writer steps

Card `car-profile-data` (dispatched 2026-09-24):

- [x] Domain `CarBody` (`suv`, `sedan`) and the car's optional body and photo id, a car without a body reading as SUV and never derived from its name or make, plus `DomainCommand` cases that set or clear them: REQ-BOARD-030 tests fail first, then `just verify` — 522a8f8
- [x] `PitstopSchemaV5` with its own car record (+ body, + photo id), a lightweight V4 → V5 stage, the app and the widget reader opening V5, V4 frozen with a shape test, the store mapping and every `CarMemoryStore` implementation reading and writing body and photo id: migration tests from V1, V2, V3 and V4 stores with data intact and a round-trip test fail first, then `just verify` — fe9bbb1
- [x] `CarPhotoStore` in `Pitstop/Infrastructure/CarPhoto/`: saves the original re-encoded as JPEG (at most 2048 px on the long side, no EXIF or location metadata) and an optional lifted PNG under `CarPhotos/` in an injected container directory, returns their URLs by id, and deletes every file of an id: REQ-BOARD-029 and REQ-BOARD-033 tests fail first, then `just verify` — 5a76746

Card `car-visual` (dispatched 2026-09-24):

- [ ] The owner's SUV and sedan placeholders in the asset catalog and a design-system `CarVisual` that resolves the fallback order (lifted photo, whole photo under the stage mask, placeholder for the body facing right, drawn through a colour role) with a label for the hero, previews in light, dark and AX-XL: REQ-DESIGN-005, REQ-BOARD-030 and REQ-BOARD-031 resolution tests fail first, then `just verify`
- [ ] A `SubjectLifter` protocol with a Vision implementation (`GenerateForegroundInstanceMaskRequest`, all instances, on device, off the main actor, returning nothing when no subject is found) and a fake: REQ-BOARD-031 tests on synthetic images fail first, then `just verify`
- [ ] `CarVisual` replaces `AbstractCarView` on the Car Board hero, the tiles and the Road lane, fed by the car's body and photo files; `AbstractCarView` and the unused `DefaultVehicleHero` image are deleted: REQ-BOARD-017 and REQ-DESIGN-005 tests fail first, then `just verify`

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|

## Coverage matrix

Generated at close by `spec_trace.py matrix`.

## Current checklist

- [ ] package approval recorded, Plan hash set, lock written
- [ ] four cards landed with review and `just verify`
- [ ] matrix exit 0, Deferred approved, `[unreleased]` lines, `State: done`
