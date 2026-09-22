# MNT-VR-001 Vehicle-reported remaining value as a rule

**Status:** Investigated (agent, 2026-09-22); owner decisions pending\
**Task:** MNT-VR-001 (`../work-plan.md`)\
**Source:** [MNT-INT-001](mnt-int-001-maintenance-intelligence.md), area 3, candidate R6\
**Register:** [`../investigations.md`](../investigations.md)\
**Contracts:** [`../../core.md`](../../core.md) (P1, C2, C3, C4, C5),
[`../../requirements/maintenance-engine.md`](../../requirements/maintenance-engine.md),
ADR [0001](../../decisions/0001-maintenance-anchors.md),
[0006](../../decisions/0006-capture-confirmation-policy.md),
[0010](../../decisions/0010-maintenance-engine-rules.md),
[0016](../../decisions/0016-question-registry.md),
[0020](../../decisions/0020-maintenance-anchor-closure.md)

This record changes no requirement, ADR or code. All values below are
fictional.

## Question

Many cars show their own service countdown ("Service in 3,200 km / 45 days").
How should PitStop hold such an owner-entered reading as a maintenance rule:
its model, precedence against the owner's interval and against completions,
staleness and expiry, capture through Pit, UI, risks, and whether to build it?

## Evidence

- **Rule family is named.** The engine contract lists "condition/vehicle-reported
  remaining value" among the rule families
  (`../../requirements/maintenance-engine.md`, "Rule families"). ADR 0010 left
  "engine-hours and vehicle-reported rules" out of scope.
- **An unused source exists.** `PolicySource.vehicleCondition` has precedence 1,
  between `defaultRecommendation` (0) and `userCustom` (2); `effective` picks one
  policy per operation by that precedence
  (`Pitstop/Domain/Maintenance/Maintenance.swift`). No code writes it
  (MNT-INT-001 evidence). REQ-MAINT-023 already says stopping tracking keeps
  "any recommendation or vehicle-condition record".
- **A policy is an interval, not a point.** `MaintenancePolicy` holds only
  `distanceIntervalKm` and `timeIntervalMonths`. The engine computes anchors as
  completion + interval and returns `unknown` with no numbers when there is no
  completion (`Pitstop/Domain/Maintenance/MaintenanceEngine.swift`,
  REQ-MAINT-016). A dashboard value is a remaining amount at one moment and
  odometer; it has no interval and needs no completion.
- **Mileage rules.** Current mileage is the newest observation from readings and
  completions with mileage; older than 90 days it is stale and feeds no
  arithmetic (`MaintenanceContext`, `MaintenanceRules.mileageStaleAfter`).
- **Anchors come from facts (ADR 0001 items 3, 7, 8).** Status derives from the
  effective policy and confirmed facts; a missing baseline is unknown; only a
  confirmed completion resets a cycle (core C5).
- **Capture boundary.** `ProposalKind` has no vehicle-report kind
  (`Pitstop/Domain/Capture/CapturePipelineTypes.swift`).
  `ConfirmationPolicy` requires compact confirmation for completions and policies
  (`ConfirmationPolicy.swift`); `DomainCommandMapper` builds exactly one command
  per permit and always writes policies as `userCustom`
  (`DomainCommandMapper.swift`).
- **Schema.** Stored policies are keyed by vehicle, operation and source
  (ADR 0007); V3 added planned events (ADR 0032); a shipped schema version is
  frozen and a new record needs a new version (ADR 0016).

## Options

| Option | Model | Problems | Verdict |
|---|---|---|---|
| V1. Write a `vehicleCondition` policy with intervals | Convert "3,200 km" into an interval | Needs a completion to anchor; the reported value is not an interval; the conversion invents one | Rejected |
| V2. Synthetic completion (back-calculate last service = anchor − interval) | Reuse the engine unchanged | Invents a completion; violates C5 and ADR 0001 item 8 | Rejected |
| V3. Vehicle report as its own observation record | `VehicleServiceReport`: operation, reported at, odometer at report, remaining km and/or days | New record, command, engine branch | **Recommended** |
| V4. Keep it a note | Remember preserves raw text | No status, no Road milestone; zero cost | Fallback if no-go |

### V3 model

```text
VehicleServiceReport
  id, vehicleID
  operationID                    (catalog ID the owner picked)
  reportedAt                     (moment of reading the dashboard)
  odometerKm?                    (required when remainingDistance is present)
  remainingDistance?, unit       (value as shown; negative = overdue; km or mi)
  remainingDays?                 (or a date shown by the car, stored as days)
  source                         (manualEntry | pitCapture)
```

Derived on read, never stored: `reportAnchorKm = odometerKm + remainingKm`,
`reportAnchorDate = reportedAt + remainingDays`. The report is a mileage
observation too (like a completion with mileage), so entering it also refreshes
the car's current mileage.

## Recommendation

Conditional **go** for V3, gated on the owner's precedence choice and on
evidence that owners actually have such dashboards (beta interviews,
INV-PROD-001).

### Precedence

A report is not a policy; it adds anchors to one operation.

1. **Validity.** Only the newest report per operation counts, and only while
   no confirmed completion of that operation is newer than it. Marking the work
   done supersedes the report (the car resets its countdown at service), and the
   operation falls back to the owner's interval, or to unknown if none.
2. **Deciding anchor (recommended: earliest wins).** With an owner interval and
   a valid report, each dimension uses the earlier anchor of the two. This
   matches "first threshold wins" (REQ-MAINT-002) and stays conservative both
   ways: an owner with a stricter cadence keeps it; a car that sees severe use
   brings the date forward. The alternative, the existing `PolicySource`
   precedence (owner over vehicle), hides a shorter car countdown and is listed
   as an owner decision.
3. **Share.** Status needs `remaining / interval`. The denominator is the
   owner's interval for that dimension when one exists, otherwise the reported
   value at report time. Example: no owner policy, 3,200 km reported: approaching
   at 480 km left (15%).
4. **Tracking.** A report on an untracked operation makes it appear on Service
   and Road like a tracked one; stopping tracking (ADR 0031) removes the owner's
   policy only and the report keeps the operation visible until the owner also
   deletes the report. REQ-MAINT-023 currently says an operation with no policy
   left leaves Service and Road, so this needs a proposed wording change (or the
   alternative: stopping tracking also deletes the report, behind the same
   confirmation).

### Staleness and expiry

- The km part follows mileage rules: with current mileage stale or unknown the
  distance anchor is blocked with the existing `DistanceBlock` reasons. The
  report itself is an observation, so it is current for 90 days.
- The day part is plain calendar arithmetic and does not go stale.
- The surface always shows the report's age ("From the dashboard, Sep 20").
  After 180 days the line says the reading is old. The report never expires
  silently: a hidden expiry would move a due operation back to unknown. The
  owner replaces it, marks the work done, or deletes it.

### Capture through Pit (core C4, ADR 0006)

- New proposal kind `vehicleServiceReport` with content
  `(operationID, remainingDistance?, unit, remainingDays?, odometerKm?, reportedAt)`.
- Always `confirmCompact`; never auto-accepted, because it changes status.
- Clarification, one field at a time (C3): operation when the text does not name
  one ("service" alone is ambiguous: oil service or inspection); odometer when a
  distance is given and no reading from the same day exists. Missing both
  distance and days is `incomplete`.
- The mapper builds one `recordVehicleServiceReport` command. The rule-based
  interpreter needs a pattern such as "dashboard says service in 3200 km and 45
  days"; the model path stays behind its rollout gate (core P4).

### UI

- Service row: status as today, plus "Car says 3,200 km / 45 days · Sep 20" as
  secondary text. The row menu gets "Enter dashboard reading" (sheet: remaining
  distance with unit, remaining days, odometer prefilled from a same-day reading)
  and "Delete dashboard reading" with confirmation naming the operation.
- Road: the milestone is placed by the deciding dimension as today; its label
  adds "from dashboard" when the report decided. No new dimension, no conversion
  (REQ-ROAD-007).

### Worked example (fictional)

Oil tracked every 15,000 km / 12 months, last done 2026-03-01 at 30,000 km:
owner anchors 45,000 km and 2027-03-01. On 2026-09-20 at 38,800 km the dashboard
shows "service in 3,200 km / 45 days": report anchors 42,000 km and 2026-11-04.
Earliest wins: distance 42,000 (3,200 left, share 3,200 / 15,000 = 0.21, up to
date), date 2026-11-04 (45 days left, share 45 / 365 = 0.12, approaching). Status
approaching by date, label "45 days left · from dashboard". Marking oil done on
2026-10-30 supersedes the report; the next anchors return to completion +
interval.

## Rejected alternatives

- **V1 and V2** (above): both invent a fact.
- **Repurposing `MaintenancePolicyRecord` with extra columns:** mixes a
  point-in-time observation with a rule, and one row per source cannot hold the
  report's date and odometer cleanly.
- **Auto-expiring reports after N days:** silently hides due work.
- **Reading the value from the car (OBD, connected-car APIs):** diagnostics and
  vehicle integration are non-goals; the owner types or says it.
- **Letting a report reset the cycle:** only confirmed work resets (C5).

## Risks

- **Units.** A dashboard in miles entered as km shifts the anchor by 60%. The
  sheet shows the unit explicitly, defaulting to the unit of the latest reading;
  the store keeps value and unit like `OdometerReading`.
- **Stale values.** An adaptive countdown changes with driving; an old report
  under-states or over-states. Mitigated by the visible age and the 180-day
  "old" wording.
- **Wrong operation.** "Service" may mean an inspection, which is not in the
  catalog. The owner picks the operation; Pit never guesses it.
- **Overdue display.** Cars show "overdue by 300 km"; negative values must be
  accepted within bounds and shown as due, not danger (REQ-ROAD-012).
- **Precedence surprise.** Earliest wins can make an owner's longer interval
  look ignored; the label names the deciding source.

## Implementation impact

- Domain: `VehicleServiceReport`, engine input of reports, earliest-anchor
  merge and denominator rule, report as a mileage observation in
  `MaintenanceContext`. `PolicySource.vehicleCondition` stays unused; removing it
  is a separate owner call (REQ-MAINT-023 names it).
- Commands: `recordVehicleServiceReport`, `removeVehicleServiceReport`.
  Validation: operation not blank; at least one remaining value; distance within
  −50,000…100,000 km and days within −365…1,095 (hypotheses); odometer required
  with a distance and plausible; `reportedAt` not in the future.
- Schema: a new `VehicleServiceReportRecord` needs the next schema version and
  a lightweight stage (ADR 0016), with migration tests from every shipped
  version.
- Capture: proposal kind, validator fields, confirmation rule, mapper case,
  rule-based pattern, confirmation copy.
- UI: Service sheet and row text, Road label suffix, en/ru/uk strings.

## Follow-up card proposal

**MNT-VR-002 Dashboard service reading as a maintenance anchor**
(implementation, about 3 days; depends on the owner decisions below; go only
after the precedence choice and beta evidence of demand, otherwise no-go and
V4 stays).

Acceptance and tests:
- Engine: a report alone yields anchors and status with no completion; a newer
  completion supersedes it; the newest report wins; earliest anchor wins per
  dimension against an owner interval; share denominator rule; stale mileage
  blocks only the km part; negative remaining reads due
  (`PitstopTests/Maintenance/VehicleServiceReportTests.swift`, new REQ IDs).
- Commands: each validation failure saves nothing; miles convert correctly.
- Persistence: round trip, delete, migration from every shipped schema.
- Capture: proposal needs confirmation; missing operation or odometer asks one
  question; mapper writes one command; nothing auto-accepts.
- Road: placement and label from the deciding anchor; no conversion.
- `just verify`; simulator smoke of entry, supersede by "Mark done", delete.

## Owner decisions

1. Build at all, or wait for beta evidence that owners have dashboard countdowns?
2. Precedence: earliest anchor wins (recommended) or owner interval always wins.
3. Old-report threshold (180 days) and whether a report ever expires.
4. Whether `PolicySource.vehicleCondition` is removed or kept for a later
   condition-based source.
