# Maintenance Engine Rules and Service Surface

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** CB-005\
**Contracts:** [`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md),
[`0001-maintenance-anchors.md`](0001-maintenance-anchors.md),
[`../requirements/car-board-screen.md`](../requirements/car-board-screen.md) (Service tile)

## Context

CB-005 is titled "Service tile summary", but a summary needs a status, and no
engine existed on `main` (the spike's engine is explicitly not a source of
truth). The work plan asks that missing scope be reported instead of silently
absorbed: this task therefore delivers the pure engine, a minimal planner, and
the Service surface, and leaves procedures and recommendations out.

## Decision

### Status from the smallest remaining share

For each effective policy the engine takes the latest confirmed completion of
that operation and computes, per dimension, `remaining / interval`. The
smallest share decides: `<= 0` is due, `<= 0.15` is approaching, otherwise up
to date. One rule covers distance-only, time-only, and distance-or-time
("first threshold wins", REQ-MAINT-002) without converting months to
kilometres.

15% was chosen over a fixed window (for example 1,000 km) because intervals
range from 7,500 km oil to 60,000 km transmission service; a fixed window is
either noise for the long interval or too late for the short one.

### Unknown is a state, not a zero

- No completion: status `unknown` and no anchor, remainder, or share. The
  engine never counts from zero or from the purchase date (REQ-MAINT-016).
- A completion without mileage cannot anchor a distance rule.
- Current mileage is the newest mileage observation: an odometer reading, or a
  completion recorded with its mileage. Marking oil done at 70,000 km says the
  car has reached 70,000 km; an earlier draft used readings only and, with an
  older reading of 68,500 km, reported 11,500 km remaining on a 10,000 km
  interval. An operation is also never behind the mileage of its own completion.
- An observation older than 90 days is stale (the same rule as Road, ADR 0008)
  and feeds no arithmetic. The distance rule is then reported as blocked, with
  the reason: mileage unknown, mileage stale, or the completion was saved
  without mileage.
- If a time rule still decides while the distance rule is blocked, the state is
  `isPartial`. The surface says "Up to date by date" and shows the blocked
  reason next to it. A calm status must not hide that half the policy could not
  be checked (core C2). If nothing can be evaluated, the status is `unknown`.

### Anchors come from actual completions

`anchorKm = completion mileage + interval`, so an early or late completion
rebaselines its own cycle and no other (REQ-MAINT-003, 004, 018). Fixed-grid
schedules stay out until a policy type asks for them (ADR 0001).

### Planner

`ServicePlanner` returns a `SuggestedServiceScope` of `due` and `dueNearby`.
When something is due the visit is now, at the car's current mileage; when
nothing is due it is planned for the most urgent approaching operation's
anchor. Measuring from the most overdue anchor instead was rejected: one badly
overdue item would push every nearby operation out of the scope.
Another operation joins as due-nearby when its own anchor is within
2,000 km or 45 days of the visit anchor. 2,000 km is the smallest window that
reproduces the contract's example (DSG at 62,000 is due nearby for a visit at
60,000); Road's visual clustering window (1,500 km, ADR 0008) is a separate
rule on purpose. The scope is derived on demand and
never stored, so it cannot change an anchor or become a plan or history
(REQ-MAINT-007, REQ-DOMAIN-008). Operations with unknown status are never
grouped.

### What the user does on the Service surface

- **Track an operation:** pick an operation and an interval in km and/or
  months. This is the "simple owner cadence" and is saved as a `userCustom`
  policy. No default recommendations are seeded, because a recommendation
  needs a verified source and none exists (core C2).
- **Mark done:** date and optional mileage, behind an explicit confirmation,
  saved as `ConfirmMaintenanceCompletion`. Only this resets a cycle (core C5).
  Marking one operation done never touches another.
  Amended by FU-5 (2026-09-24): `ReplaceMaintenanceCompletionCommand`
  (`DomainCommand.replaceMaintenanceCompletion`) is the second command that
  resets a cycle, issued only as the owner's explicit "Replace with mine" in
  Mark as done: it revokes the Pit entries the prompt named and confirms the
  owner's completion in one save (REQ-MAINT-040, REQ-NEW-3, proposed). No
  proposal maps to it.
- **Change interval** re-saves the owner's policy for a tracked operation.
- **Undo the last "done"** issues `RevokeMaintenanceCompletionCommand`, for a
  tap or a number entered by mistake; the cycle returns to the previous
  completion or to unknown. Stored facts must stay correctable (core P1). No
  proposal maps to this command.
- Remaining days are rounded toward zero and the wording follows the status, so
  half a day either side of the anchor reads "almost there" or "reached" and
  never "0 days past" on an approaching operation.
- Due uses amber attention colour and words; nothing is shown as danger, and
  there is no health score.

## Not in this task

Procedure components and their provenance (REQ-MAINT-008…011, 019…021: with no
verified procedure, nothing is preselected, which is the required behaviour),
recording a multi-operation visit with linked completions (REQ-MAINT-014, 015),
engine-hours and vehicle-reported rules, accepted Service Plans, and the
"Consider" list. They need owner scoping; see the delivery brief.

## Rejected alternatives

- **Seeding manufacturer intervals for a default car.** Invented truth.
- **Estimating current mileage from past readings.** Needs an explicit,
  owner-approved projection model (MNT-INT-001).
- **Persisting computed status.** It would go stale and become a second
  source of truth.
