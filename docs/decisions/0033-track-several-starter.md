# "Track Several" Starter

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-22); owner review pending\
**Task:** MNT-PRE-001\
**Builds on:** [`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md)
(owner cadence, Track sheet), [`0020-maintenance-anchor-closure.md`](0020-maintenance-anchor-closure.md)
(policy source separation, no seeded recommendations),
[`0031-stop-tracking-an-operation.md`](0031-stop-tracking-an-operation.md)
(a wrong pick can be undone), [`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md)
(one confirmation before a write), [`0021-analytics-boundary.md`](0021-analytics-boundary.md)
(no event without an owner question)\
**Source:** [MNT-INT-001](../planning/investigations/mnt-int-001-maintenance-intelligence.md),
area 2 "Presets", options P1 and P2\
**Contracts:** [`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md)
(REQ-MAINT-025…029, proposed); core C2 (never invent facts), P1 (stored data
can be corrected)

## Context

Service tracks one operation per sheet. An owner who knows several intervals
repeats the same sheet for each. MNT-INT-001 rejected numeric presets (an
interval chosen by the app is either invented truth or blocked on a verified
source) and gave a conditional go for an operation-set starter: the owner picks
operations, optionally answers two car-type questions that only reorder the
list, enters every interval, confirms once, and each item is saved through the
existing command as the owner's own policy. Its prerequisite, a way to stop
tracking a wrong pick, shipped in ADR 0031.

The record left three owner questions. The owner delegated them on 2026-09-21
("do everything"); the answers below are agent decisions that the owner may
still reverse.

## Decision

1. **Build now.** The starter reuses the existing command, validation and
   engine; it adds no schema, no command and no stored data, so waiting for
   beta evidence would save little. The measurement below needs events that
   stay proposed until the analytics gate passes.
2. **Entry.** "Track several" is a toolbar button on Service (next to "Track
   an operation") and a second button in Service's empty state. It is disabled
   until Service has loaded successfully (while loading or after a failed load
   every operation would look untracked, and saving one that is tracked would
   silently replace the owner's interval) and when every catalog operation is
   already tracked.
3. **Four steps in one sheet** (`TrackSeveralView`, `TrackSeveralViewModel`):
   - *Choose.* Two optional questions, gearbox (dual-clutch automatic, other
     automatic, manual) and drive (all-wheel, front or rear), both starting at
     "Not specified". Below them, every untracked catalog operation as a
     multi-select list. Nothing is selected at the start.
   - *Intervals.* For each selected operation, the Track sheet's two fields
     (distance, time) and a row of quick picks under each field. "Next"
     validates each item with the same rule as the Track sheet
     (`OwnerInterval.policy`, extracted from `ServiceViewModel.track`: blank or
     positive whole numbers, at least one filled, same upper limits) and marks
     every failing item by name in its section footer. Because the failing
     section may be off screen, a failed "Next" also scrolls to the first
     failing item in list order and posts a VoiceOver announcement naming every
     failing item (the single Track sheet shows an alert instead). No item
     moves on until all pass.
   - *Review.* One confirmation lists every operation with its interval in the
     owner's numbers. Its button ("Track: N") is the only path to a write.
   - *Results.* Each item reads "Saved" or "Not saved". With a failure, a
     "Try again: N" button saves the failed items only, and the footer says the
     saved ones stay saved.
4. **Saves run one at a time.** `apply()` reads the vehicle once and executes
   one `setMaintenancePolicy` command per item with `source: .userCustom`,
   through `CarMemoryStore.execute`, in review order. A failed command marks
   that item failed and the loop continues, so a failure part way leaves the
   earlier and later items saved and is reported per item (MNT-INT-001 gap 1).
   A failed vehicle read marks every pending item failed. Retry skips items
   already saved. There is no batch command: a transaction would turn one bad
   item into a total failure the owner cannot see, and the existing command
   already validates each item.
5. **Quick picks are common owner choices, not recommendations.** Distance:
   5,000 / 7,500 / 10,000 / 15,000 km; time: 6 / 12 / 24 months, the same set
   for every operation (`IntervalQuickPicks`). None is preselected; a tapped
   pick fills the field exactly like typing and stays editable; a pick is
   highlighted only while the field holds that number. The step's text says
   the buttons are common choices, not advice for this car, and to check the
   owner's manual. No copy says "recommended" and no pick is tied to a make,
   model or operation, so no manufacturer claim is made (core C2).
6. **Car-type answers reorder only and are never stored.** A dual-clutch
   answer moves "DSG service" to the top and an all-wheel answer moves "AWD
   coupling service" to the top; "other automatic" or "manual" and "front or
   rear" move the same operation to the end. Nothing is hidden and nothing is
   selected by an answer; the catalog order holds otherwise. The answers live
   in the sheet's view model only and are dropped with it: no command, no
   vehicle fact, no analytics. The copy says so ("They are not saved"). Turning
   them into vehicle facts would need its own decision (MNT-INT-001 area 1
   applicability dimensions).
7. **Cancel saves nothing.** Cancel is offered on the first three steps. It
   marks the view model cancelled and dismisses; a cancelled model ignores
   `apply()`, so even a save task queued before the sheet closed writes
   nothing. Swipe-to-dismiss is disabled on the interval and review
   steps and while saving, so typed intervals are not lost by accident.
8. **Surfaces reload.** After a save that stored at least one item, the sheet
   calls back into `ServiceViewModel.load()`. Road loads on appear and Car
   Board refreshes on return (ADR 0009), so both read the new policies without
   new wiring.
9. **Pit and accessibility.** The sheet is a `ServiceSheet` case, so Service's
   existing `.pitActivity(.modalTask, …)` covers it; its text fields report
   editing like the Track sheet. Selected rows and a highlighted quick pick
   carry the `isSelected` trait; status is always a word next to the icon;
   quick picks scroll horizontally at large text sizes; each quick pick has a
   hint that it fills the value.
10. **Analytics: proposed only.** No maintenance event exists in the taxonomy
    (ADR 0021, 0031), so none is collected. `track_several_applied` is added to
    `docs/operations/analytics.md` as a `REVIEW` proposal for the MNT-INT-001
    measurement.

## Consequences

- An owner can start tracking several operations in one pass, and a wrong pick
  is removed with "Stop tracking" (ADR 0031).
- `ServiceViewModel.track` and the starter share `OwnerInterval`, so their
  validation cannot drift.
- An operation outside the catalog is never offered, as in the Track sheet.
- The quick-pick values are code constants; changing them is a code change and
  an update to this ADR.

## Rejected alternatives

- **Numeric presets for a car class** (MNT-INT-001 P3). Unsourced values break
  core C2; sourced values are blocked on area 1.
- **Preselected quick picks or preselected operations.** Either would save the
  app's choice when the owner only taps "Next".
- **One transactional batch command.** Hides which item failed and adds a
  command with no other user.
- **Storing gearbox and drive as vehicle facts.** Useful later for
  recommendations, but it creates car facts from a reorder question and needs
  its own owner decision.
- **Hiding operations that the answers make unlikely.** A manual car can still
  have a service the owner wants to track by another name; hiding would decide
  for the owner.
- **Per-operation quick-pick values** (for example a different set for brake
  fluid). That would read as advice per operation, which is exactly a
  recommendation.
- **Reusing the single Track sheet in a loop.** One confirmation per operation
  instead of one for the whole set, and no place to report partial failure.

## Measurement (needs the proposed events)

From MNT-INT-001: tracked operations per car after 7 days with and without the
starter, sheet abandonment, share of intervals changed within 30 days, and quick
pick versus typed share (feeds INV-MNT-003).

## Verification

- `PitstopTests/Maintenance/TrackSeveralTests.swift`: nothing selected and no
  value filled at the start; selection and deselection; per-item validation
  with the Track sheet's cases; a failed "Next" exposes the invalid items and
  the first one in list order and counts each attempt; a quick pick fills and
  stays editable; nothing saved before the confirmation; after Cancel a filled
  review saves nothing even when `apply()` still runs; the starter is offered
  only after a successful Service load; confirmed items saved as
  `userCustom` and Service reloaded; partial failure reported per item and
  retry saves only the failed item; total failure; no second save after
  success; answers reorder only and write nothing; review follows the list
  order; Service, Car Board and Road show the new policies.
- `PitstopTests/Persistence/SwiftDataTrackSeveralTests.swift`: confirmed items
  survive a reopen on disk as owner policies, and the vehicle is unchanged.
- Not verified on screen unless noted in the work plan: the sheet in en, ru
  and uk, VoiceOver order and AX5 text sizes.
