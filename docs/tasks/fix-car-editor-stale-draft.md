# Task — The car editor must not write back fields Pit changed while it was open

Assignee: Pitstop (local_1b8d76c5-4a66-436c-9d0f-8e59157a2252), host Claude desktop
State: claimed
Requested by: owner (direct, 2026-09-24) — found by the Release 1.2.0 gate review
Evidence: pending
Depends-on: rd-012-car-profile
Parallelism: none
Profile: fix
user-visible: Saving the car editor after Pit recorded a new mileage or name no longer puts the old value back.

## Current status and authorization

Current outcome: claimed; a release blocker for TestFlight 1.2.0.
Authorized scope: the owner approved the RD-012 pilot plan in the Pitstop
session on 2026-09-24 (ExitPlanMode), whose ship stage runs the gate review of
`main..redesign/ios27` before asking to push `main`; the owner chose "1.2.0
after RD-012 (Recommended)". The gate review's HOLD verdict makes this defect a
release blocker inside that stage. No new requirement.
Blocking decisions: none.
Permitted deviations: none.
Material assumptions: none.
Next step: dispatch the writer from the commit that adds this brief.
Requirements: REQ-PIT-026, REQ-BOARD-026
Acceptance specs: a failing test first for each scenario below, then passing
in `just verify`.
Owned files: `Pitstop/Features/CarBoard/CarEditorView.swift`,
`Pitstop/Features/CarBoard/CarBoardViewModel.swift`, and their tests.
Out of scope: the round's backlog lows (FU-6, FU-7), other editors (Mark as
done already has its snapshot guard, FU-3/FU-5).
Failure conditions: an edited field is not saved; the same-number save of a
stale mileage stops recording a fresh reading (REQ-BOARD-026); a value Pit
recorded while the editor was open is overwritten by an untouched field.

## Defect

Gate review, 2026-09-25, Review SHA `f660d4f`:
`Pitstop/Features/CarBoard/CarBoardViewModel.swift:208` (medium, blocking).
RD-010 puts Pit inside the car editor sheet. The editor's draft is the car as
it was when the sheet opened (`CarEditorView.swift:90`), and a capture closing
over the sheet reloads the board. Saving then compares that untouched draft
with fresh state:
- The board shows 47 560 km; the owner opens the editor; Pit in the sheet
  records 48 200 km; the owner changes only the body or the photo and saves.
  The untouched "47560" differs from 48 200, so a reading of 47 560 dated now
  is recorded and the mileage goes backwards on Car Board, Service, Road and
  the widget.
- A name Pit records while the editor is open is reverted the same way.

Fix direction: compare the draft with the car as the editor saw it when it
opened (a snapshot, as Mark as done does), so only fields the owner changed
are written. The REQ-BOARD-026 same-number save of a stale mileage still
records a fresh reading when nothing newer was recorded since the editor
opened.

## Evidence history

- 2026-09-25: claimed from `redesign/ios27` at `f660d4f`.
- 2026-09-25: writer READY at `bb3284c` (a `CarEditorOpening` snapshot;
  scenario tests failed first with 4 issues); `just verify` OK; `hasPhoto`
  stands in for the photo id because the photo commands act on the current
  id. Round 1 review: 1 medium; repair 1 dispatched.

### Round 1 review — fix-car-editor-stale-draft (2026-09-25)

Review SHA: bb3284c

- [medium][blocking][new] Pitstop/Features/CarBoard/CarBoardViewModel.swift:268 — "nothing newer arrived" is read from the board's cached mileage, which a failed or unfinished reload after Pit's capture leaves stale; a stale opening, Pit records 48 200 km, the reload fails or lags, a body-only save records 47 560 km dated now and the mileage goes backwards again

### Repair 1 dispatch — Decide the stale same-number save from the store (2026-09-25)

Objective: Before an untouched stale mileage is recorded again, read the
store's newest mileage observation; record it only when that read succeeds
and nothing newer than the opening exists, and never write an untouched
field when the read fails.

Sources: REQ-BOARD-026, REQ-PIT-026; round 1 review finding
`CarBoardViewModel.swift:268` (medium).

Intended deviations: none

Boundaries: rebase onto the round head first (KIT-D-024); owned
`Pitstop/Features/CarBoard/CarBoardViewModel.swift` and
`PitstopTests/CarBoard/CarEditorOpeningTests.swift`; one commit, a failing
test first for a failed and for a skipped reload after Pit's capture.

Output: a Repair 1 section appended to the writer report.

## Untested scope

- Pit over the car editor on screen (needs taps): 1.2.0 What to Test item 16.

## Writer steps

- [ ] Repair 1: the stale same-number save reads the store's newest mileage first and writes nothing untouched when that read fails: REQ-BOARD-026 tests with a failed and a skipped reload fail first, then `just verify`
- [ ] The editor saves only the fields the owner changed since it opened, and the stale-mileage same-number save still records a reading when nothing newer arrived: REQ-PIT-026 and REQ-BOARD-026 tests (Pit records a mileage and a name while the editor is open, then a body-only save) fail first, then `just verify`

## Current checklist

- [ ] failing tests first, fix, `just verify`, one review, `State: done`
