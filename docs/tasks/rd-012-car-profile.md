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

Current outcome: round opened on `RD-012/car-profile` (cut from
`redesign/ios27` at `b6aab84`); no card dispatched.
Authorized scope: the owner in this session on 2026-09-24: "RD-012 делаем как
pilot round по новому SDLC flow: в старом brief не начинай, оркестратор
пришлёт задачу, открой её в plan mode."; the RD-012 pilot plan approved
through ExitPlanMode (Part B: opening, four cards, close, ship); release
scope "1.2.0 after RD-012 (Recommended)". The pilot-minimum package was
approved by the owner on 2026-09-24 ("да", kit `docs/tasks/ios-sdlc-review.md`).
Package approval of this round's requirements and cards: pending (one
`AskUserQuestion`, quoted here verbatim before the first dispatch).
Blocking decisions: the package approval above.
Permitted deviations: none.
Material assumptions: the simulator's Vision may return no foreground
instance, so the lifted path is checked on a device (What to Test); checked
at card `car-visual` by running the fake and the Vision path in tests.
Next step: ask the owner for the package approval of this Plan hash; then
flip REQ-BOARD-032, REQ-BOARD-033, REQ-BOARD-034 and ADR 0040, run
`spec_trace.py lock --write` and dispatch card `car-profile-data`.
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
`Conflicts found`.

### car-profile-data dispatch — Body, photo id and photo files (2026-09-24)

Objective: Add the car's body choice and photo id to the domain and to a new
schema V5, freeze V4, and add a file store for car photos in the App Group
container, with migration tests from every earlier version.

Sources: REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-033; ADR 0040 "Storage",
"Body", "Schema"; ADR 0007 (frozen versions); ADR 0036 (App Group location).

Intended deviations: none

Boundaries: owned `Pitstop/Domain/Vehicle/`, `Pitstop/Infrastructure/Persistence/`,
new `Pitstop/Infrastructure/CarPhoto/`, `Shared/` only if the store location
helper lives there, and matching tests under `PitstopTests/`. Do not touch
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
colour role.

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

## Untested scope

- The lifted path on real photos (Neural Engine) and `PhotosPicker` with the
  owner's library: device checks in the 1.2.0 What to Test.

## Writer steps

Filled per card at its dispatch.

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|

## Coverage matrix

Generated at close by `spec_trace.py matrix`.

## Current checklist

- [ ] package approval recorded, Plan hash set, lock written
- [ ] four cards landed with review and `just verify`
- [ ] matrix exit 0, Deferred approved, `[unreleased]` lines, `State: done`
