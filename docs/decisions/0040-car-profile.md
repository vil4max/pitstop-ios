# Car Profile: the Owner's Photo, the Chosen Body and the Car Avatar

**Status:** Accepted (owner, 2026-09-24, RD-012 package approval: "Approve the package")\
**Task:** RD-012 ([`../tasks/rd-012-car-profile.md`](../tasks/rd-012-car-profile.md))\
**Builds on:** [`0007-persistence.md`](0007-persistence.md) (versioned schemas, frozen
shipped versions), [`0036-app-group-store-and-next-service-widget.md`](0036-app-group-store-and-next-service-widget.md)
(the App Group container), [`0038-ios27-surface-tiers.md`](0038-ios27-surface-tiers.md) (the stage tier),
[`0003-logging.md`](0003-logging.md) and [`0021-analytics-boundary.md`](0021-analytics-boundary.md) (what never leaves the device)\
**Replaces:** `AbstractCarView` (`Pitstop/DesignSystem/Components/AbstractCarShape.swift`)\
**Contracts:** REQ-BOARD-017, REQ-BOARD-029, REQ-BOARD-030, REQ-BOARD-031, REQ-BOARD-032,
REQ-BOARD-033, REQ-BOARD-034, REQ-DESIGN-005 ([`../requirements/car-board-screen.md`](../requirements/car-board-screen.md)
"Car Hero" and "Car profile", [`../requirements/product-design.md`](../requirements/product-design.md) "Car image")

## Context

The car is drawn as an abstract shape (`AbstractCarView`) on the Car Board stage, in the
Car Board tiles and on the Road lane. The owner decided on 2026-09-22 (proposal §3.6c)
that the car is the owner's own photo, lifted onto the stage, or a neutral side-view
placeholder for the body the owner chose, and that a small avatar of it appears where
seeing the car helps. The requirements fix what the owner sees; this record fixes where
the photo lives, how the lift runs, and what may never happen to the photo.

## Decision

- **Picking.** `PhotosPicker` in the car editor, the only entry (no camera, no
  permission prompt). The photo is optional and never part of first launch
  (REQ-BOARD-032).
- **Storage.** Files in the App Group container, in
  `Library/Application Support/CarPhotos/`, next to the store (ADR 0036), so a widget
  can read them later without a timeline entry (REQ-BOARD-029). Per photo, named by a
  new random id: the original re-encoded as JPEG at most 2048 px on its long side (the
  re-encode drops EXIF and location metadata), and, when the lift succeeds, the lifted
  cut-out as PNG with transparency. The car row stores only that id; no image bytes
  enter the store. Replacing or removing the photo deletes every file of the old id
  (REQ-BOARD-033).
- **Body.** A domain value `CarBody` (`suv`, `sedan`) chosen in the car editor; a car
  without a choice reads as SUV. It is never derived from the name, a make or a locale
  (REQ-BOARD-030, REQ-DESIGN-005).
- **Schema.** `PitstopSchemaV5` adds the body and the photo id to its own copy of the
  car record, with a lightweight V4 → V5 stage; V4 is frozen like V1–V3 (ADR 0007).
  Shipped stores are V1 (`tf-1.0.0-1`, `tf-1.1.0-1`), V2 (`tf-1.1.0-2`) and V4
  (`tf-1.1.0-3`); each migrates to V5 with its data intact, and V3 does too.
- **Lift.** Vision's `GenerateForegroundInstanceMaskRequest` (iOS 18+), on device, run
  once when the photo is saved, off the main actor, over all detected instances. No
  instance or an error stores the original only; the stage then shows the whole photo
  under the stage mask and says nothing (REQ-BOARD-031). The lift sits behind a
  protocol so tests use a fake.
- **Placeholders.** `docs/design/assets/car-placeholder.png` (SUV) and
  `car-placeholder-sedan.png`, side view facing right, move into the asset catalog and
  render through a design-system colour role, not a literal (REQ-DESIGN-004).
  Provenance: generated with AI by the owner on 2026-09-22 and supplied for PitStop,
  recoloured, background removed and mirrored (`docs/design/assets/README.md`); neither
  depicts a real make or model; the generator's name is not recorded.
- **One component.** A design-system `CarVisual` draws the fallback order (lifted
  photo, whole photo under the mask, placeholder for the body) on the stage, the tiles
  and the Road lane; a `CarAvatar` draws the round avatar, 28 pt in detail headers and
  44 pt in the Pit sheet's saved state and question card, hidden from VoiceOver
  (REQ-BOARD-034). The hero car stays decorative for VoiceOver, as the mockup
  draws it (`ios27-mockups.html:462`); REQ-BOARD-024 allows a label or a
  decorative mark. (Corrected at round close: the accepted text said "keeps a
  label", which neither the code before RD-012 nor the mockup did.)
- **Privacy.** The photo, its id and its files never reach analytics, logs, the
  network, a widget timeline entry or the repository. No analytics event is added for
  the photo or the body.
- **Clean-up.** The unused catalog image `DefaultVehicleHero` (a real production car,
  ADR 0009) is deleted with `AbstractCarView`. Git history is not rewritten.

## Verified

- Coverage matrix at RD-012 close (`just ci` bundle, 2026-09-25): REQ-BOARD-017, 029, 030,
  031, 032, 033, 034 and REQ-DESIGN-005 each passed, 0 GAP.
- Migration tests open V1, V2, V3 and V4 stores under V5 with their data intact; V4 has a
  frozen shape test.
- `CarPhotoStore` tests: the files carry no Exif segment, the original is at most 2048 px,
  deleting an id removes every file.
- Simulator (iPhone 17, iOS 27.0): the SUV placeholder faces right on the hero and the Road
  tile in light, dark and AX-XXXL; Road's header shows the 28 pt avatar; Car Board's header
  shows none.
- Not verified here: the Vision cut-out (the simulator has no inference context, so the
  shape test is skipped there), `PhotosPicker` with a real library, the car editor and the
  avatar in the Pit sheet on screen — the 1.2.0 What to Test, items 12–16.

## Rejected alternatives

- **SwiftData external storage (`.externalStorage`).** Keeps the bytes under the
  store's control, but the photo would be a database value, which REQ-BOARD-029's
  source section forbids, and a widget could not read it as a plain file.
- **Keep only the cut-out.** Smaller, but a failed or poor lift could never be redone
  and REQ-BOARD-031's whole-photo fallback would have nothing to show.
- **Lift at render time.** No second file, but Vision would run on every stage render
  and on each avatar.
- **Camera capture.** Out of scope for RD-012 by owner decision; `PhotosPicker` needs
  no permission.
- **A body guessed from the name or a make.** Forbidden by REQ-BOARD-030 and
  REQ-DESIGN-005.

## Consequences

- The store opens V5; a store written by 1.2.0 cannot be opened by 1.1.0.
- Photos add up to a few megabytes per car in the App Group container; removing the
  photo frees them.
- The data widgets may show the avatar later by reading the file (not in RD-012).
- A real-photo lift runs on the Neural Engine; the simulator may fall back to the whole
  photo, so the lifted path is a device check in the 1.2.0 What to Test.
