# Dashboard Service Reading as a Maintenance Anchor

**Status:** Accepted (owner decision, 2026-09-22): build now without waiting
for beta evidence; the earliest anchor wins per dimension; a reading is called
old after 180 days and never expires; `PolicySource.vehicleCondition` stays
unused; REQ-MAINT-023 is reworded so a reading keeps an untracked operation
visible until the reading is deleted. The four implementation choices marked
"owner decision" below were approved by the owner on 2026-09-22\
**Task:** MNT-VR-002\
**Builds on:** [`0001-maintenance-anchors.md`](0001-maintenance-anchors.md)
(anchors come from facts), [`0006-capture-confirmation-policy.md`](0006-capture-confirmation-policy.md),
[`0008-road-projection-rules.md`](0008-road-projection-rules.md),
[`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md),
[`0016-question-registry.md`](0016-question-registry.md) (schema versions),
[`0020-maintenance-anchor-closure.md`](0020-maintenance-anchor-closure.md),
[`0031-stop-tracking-an-operation.md`](0031-stop-tracking-an-operation.md),
[`0032-planned-dated-events.md`](0032-planned-dated-events.md) (schema V3),
[`0033-track-several-starter.md`](0033-track-several-starter.md)\
**Source:** [MNT-VR-001](../planning/investigations/mnt-vr-001-vehicle-reported-remaining.md),
option V3\
**Contracts:** [`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md)
(REQ-MAINT-023 rewording, REQ-MAINT-030…039, proposed),
[`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md)
(REQ-ROAD-026, proposed); core C2 (no invented facts), C4 (one capture
pipeline), C5 (only confirmed work resets a cycle)

## Context

Many cars show their own service countdown ("Service in 3,200 km / 45 days").
The engine contract names "condition/vehicle-reported remaining value" as a rule
family, but a policy in PitStop is an interval, and the engine derives anchors
only from a completion plus that interval. A dashboard value is a remaining
amount at one moment and one odometer: it has no interval and needs no
completion. Writing it as a policy or as a synthetic completion would invent a
fact (MNT-VR-001, options V1 and V2).

## Decision

1. **Its own observation record.** `VehicleServiceReport`: operation, reported
   date, odometer at the time, optional remaining distance with its unit (km or
   mi, stored as entered, like `OdometerReading`), optional remaining days. At
   least one remaining value is required; the odometer is required with a
   distance; negative values (overdue) are accepted within −50,000…100,000 km
   and −365…1,095 days. It is not a `MaintenancePolicyRecord`, writes no
   completion, and `PolicySource.vehicleCondition` stays unused.
2. **Derived on read.** Report anchors are `odometer + remaining km` and
   `reported date + remaining days`, computed in `MaintenanceEngine` and never
   stored. Miles convert to kilometres only for this arithmetic.
3. **Validity.** Only the newest reading per operation counts, and only while no
   confirmed completion of that operation supersedes it (owner rule). On
   different days the calendar day decides: a completion on a later day
   supersedes the reading. On the same day the order in which the two were
   saved decides (agent decision within the owner's rule, 2026-09-22), never the
   times they carry, because "Mark done" keeps the time its sheet was opened.
   The store stamps each reading with the newest completion of the operation
   already saved at that moment (`completionIDAtEntry`); a same-day completion
   other than that one was saved after the reading and supersedes it. So "300 km
   overdue" entered in the morning and "Mark done" in the afternoon leave the
   operation on the owner's interval, while a reading entered after "Mark done"
   keeps counting. Every entered reading keeps its own row and ID: the engine
   counts only the newest per operation, older ones stay mileage observations,
   and a replayed confirmation of an older proposal is rejected as a duplicate
   (`duplicateRecord`, reported by Remember as already saved) instead of
   overwriting the newer reading. Deleting removes every row of the
   operation.
4. **Earliest anchor wins per dimension** between the owner's interval and the
   reading; an exact tie goes to the owner's interval (owner decision,
   2026-09-22). The share denominator is the owner's interval for that
   dimension when one exists (for time, its length from the reading's date),
   otherwise the reported value at report time. An already-overdue reading with
   no owner interval uses the magnitude of its value, so the sign still comes
   from what is left (owner decision, 2026-09-22).
5. **Staleness.** A reading with an odometer is a mileage observation, like a
   completion with mileage: `MaintenanceContext` and the Road rate history read
   every stored reading, not only the newest. The distance part follows the 90-day mileage rule and the existing
   `DistanceBlock` reasons; the day part is calendar arithmetic and never goes
   stale. When the owner's distance rule cannot be evaluated because the
   operation has no completion yet, the distance side is blocked
   (`DistanceBlock.completionMissing`), so a status decided by the reading's days
   alone is shown as partial ("up to date by date") rather than complete
   (core C2).
6. **Age, never expiry.** Service always shows the reading's date; after 180
   days the line says the reading is old. A reading never disappears on its own:
   the owner replaces it, marks the work done, or deletes it.
7. **Visibility.** A stored reading keeps its operation on Service and Road
   like a tracked one, including an operation the owner does not track and one
   whose tracking the owner stopped. A superseded reading still keeps the row
   until it is deleted, but it decides nothing, and the row says so (owner
   decision, 2026-09-22). Such an operation stays offered under Track, because
   it has no rule.
8. **Service surface.** The row keeps its status and adds "Car says 3,200 km /
   45 days · Sep 20" (in the unit the car showed; overdue said in words). The
   row menu gains "Enter dashboard reading" (sheet: remaining distance, an
   explicit km / mi choice defaulting to the unit of the newest reading,
   remaining days, and the odometer, prefilled from a same-day reading) and
   "Delete dashboard reading" behind a confirmation that names the operation and
   says that completions, History and the interval stay.
9. **Road.** The milestone is placed by its deciding dimension as before; the
   fact label gains "from dashboard" when the reading decided it
   (`RoadMilestone.isFromDashboard`, `RoadMilestone.distanceText`). No new
   dimension and no conversion (REQ-ROAD-007).
10. **Capture.** Proposal kind `vehicleServiceReport`, always `confirmCompact`.
    Clarification asks one field at a time: the operation first (a bare
    "service" is never mapped to one), then the odometer when a distance is
    given; with neither remaining value the proposal is incomplete. The mapper
    builds one `recordVehicleServiceReport` command whose ID is the proposal's.
    The rule-based interpreter reads phrasings such as "dashboard says service
    in 3200 km and 45 days" or "приборка показывает сервис через 3200 км и 45
    дней". It needs both a mention of the car's display and a countdown marker
    right before the number ("in", "через", "до ТО", "осталось", "залишилось",
    "overdue by", "просрочено на", "прострочено на") or right after its unit
    ("left", "overdue"); a second value joined by "and" continues the
    countdown. "Overdue" / "просрочено" / "прострочено" alone count as naming
    the display, and a capture that says "overdue" but has no readable
    countdown keeps only its words: its number is never written as a mileage. A
    number after "пробег", "odometer" or a bare "на", or followed by "пробега" or
    "odometer", is never a remaining value, so "машина показывает 91500 км"
    stays an odometer reading, "пробег 38800 км, приборка показывает ТО через
    3200 км" yields odometer 38,800 and 3,200 km left, and "приборка показывает
    ТО через 45 дней и 38800 км пробега" yields 45 days left and odometer
    38,800. The completion rule runs first, so
    "поменял масло на 84200 км, машина пишет следующее через 15000 км" stays the
    completion it reports; the dashboard rule runs before the odometer rule. The
    Foundation Models path is unchanged and stays behind its gate (core P4,
    ADR 0027). Siri reads the operation and the values back in its confirmation,
    joined with "and" rather than the slash of the Service line, and asks "Which service does the car mean?" for a missing operation; it does
    not collect the remaining value by voice (owner decision, 2026-09-22), so a
    capture without one can only keep its words.
11. **Schema V4.** `VehicleServiceReportRecord` is added in `PitstopSchemaV4`
    with a lightweight V3 → V4 stage; V3 is now frozen like V1 and V2. Besides
    the reading's own fields it stores `completionIDAtEntry`. No completion field
    was added: the completion entity is the frozen V1 class. A stored unit this
    version cannot read drops the distance part rather than guessing.

## Worked example (fictional car)

Oil tracked every 15,000 km / 12 months, last done at 30,000 km: owner anchors
45,000 km and a year later. The dashboard later shows "service in 3,200 km / 45
days" at 38,800 km: report anchors 42,000 km and 45 days ahead. Distance
42,000 (share 3,200 / 15,000 = 0.21, up to date); date 45 days (share about
45 / 365 = 0.12, approaching). Status approaching by date; Road reads
"45 days left · from dashboard". Marking oil done afterwards supersedes the
reading and the anchors return to completion + interval.

## Consequences

- An owner with a car countdown gets a status and a Road milestone without
  knowing when the work was last done, and without any invented completion.
- `MaintenanceOperationState.policy` is optional: an operation may be on
  Service with a reading only. Stop tracking stays offered only for a
  `userCustom` policy.
- A post-service reading entered before "Mark done" on the same day is
  superseded by that completion, so the operation falls back to the owner's
  interval (or to unknown without one). This loses little: the car's
  post-service countdown is about one interval, which is what the owner's
  interval already says.
- Known limitation: deleting a reading removes its rows, so replaying the
  confirmation of a deleted Pit capture (the same proposal confirmed again)
  brings it back. Rejecting it would need a record of deletions; a replay
  needs the same, still open, capture sheet, so the limitation is recorded
  rather than built around (agent choice, 2026-09-22).
- A fresh reading with no owner interval starts at a 100% share, because the
  reported value is its own denominator (REQ-MAINT-033): "service in 200 km"
  reads "up to date" until 15% of those 200 km remain. This is the approved
  rule, kept visible here because it can surprise with a short countdown.
- The capture analytics `intent` property gains the value
  `vehicle_service_report` (proposed in `docs/operations/analytics.md`).
- The distance part of a reading is only as good as the odometer entered with
  it; a wrong odometer shifts the anchor, as a wrong completion mileage does.

## Rejected alternatives

- **V1: a `vehicleCondition` policy with intervals** converted from the
  countdown: still needs a completion to anchor, and the conversion invents an
  interval.
- **V2: a synthetic completion** (anchor − interval): invents a completion and
  violates C5 and ADR 0001 item 8.
- **Repurposing `MaintenancePolicyRecord` with extra columns:** mixes a
  point-in-time observation with a rule; one row per source cannot hold the
  reading's date and odometer cleanly.
- **Owner interval always wins** (existing `PolicySource` precedence): hides a
  shorter car countdown; the owner chose earliest-wins.
- **Auto-expiring readings after N days:** silently moves due work back to
  unknown.
- **Stopping tracking also deletes the reading:** the owner chose to keep them
  separate; the reading is deleted on its own, behind its own confirmation.
- **Reading the value from the car (OBD, connected-car APIs):** diagnostics and
  vehicle integration are non-goals.
- **Letting a reading reset the cycle:** only confirmed work resets (C5).
- **Guessing the operation from "service":** it may mean an inspection that is
  not in the catalog; Pit asks.
- **Superseding by the times the records carry** (timestamp or date-picker
  time): "Mark done" keeps the time its sheet was opened, so a same-day order
  read from those times can be wrong either way.
- **The reading wins on the same day** (the first cut of this slice): "300 km
  overdue" in the morning and "Mark done" in the afternoon left the operation
  due after the work was done.
- **A saved-at timestamp on completions:** the completion entity is the frozen
  V1 class, so a new field means a new copy of a shipped entity and its
  migration; stamping the reading with the completion it followed gives the
  same same-day order with one field on the unshipped V4 record (agent
  decision within the owner's "completion supersedes" rule, 2026-09-22).
- **Keeping only one row per operation:** a replayed confirmation of an older
  proposal would then find no duplicate and overwrite the newer reading.
- **A countdown rule that matches any number near "dashboard":** it turned
  plain odometer readings and completions into readings (review of the first
  cut).

## Follow-ups

- Simulator smoke of entry, supersede by "Mark done" and delete, and the ru/uk
  strings on screen (listed under "Not verified on screen").
- Whether `PolicySource.vehicleCondition` is removed stays a separate owner call.
- The proposed analytics events await the telemetry change gate.
