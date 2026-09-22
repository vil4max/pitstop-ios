# ROAD-EST-001 Mileage-rate estimate for distance milestones

**Status:** Investigated (agent, 2026-09-22); approved by the owner 2026-09-22 and
implemented as ROAD-EST-002 ([ADR 0034](../../decisions/0034-mileage-rate-estimate.md))\
**Task:** ROAD-EST-001 (`../work-plan.md`)\
**Source:** [MNT-INT-001](mnt-int-001-maintenance-intelligence.md), area 3, candidate R5\
**Register:** [`../investigations.md`](../investigations.md)\
**Contracts:** [`../../core.md`](../../core.md) (C2),
[`../../requirements/road-domain-and-ui.md`](../../requirements/road-domain-and-ui.md) (REQ-ROAD-007),
ADR [0008](../../decisions/0008-road-projection-rules.md),
[0010](../../decisions/0010-maintenance-engine-rules.md),
[0032](../../decisions/0032-planned-dated-events.md)

This record changes no requirement, ADR or code. All readings and dates below
are fictional.

## Question

Can Road show an approximate date for a distance milestone ("oil change around
December") derived from the car's reading history without breaking core C2 and
REQ-ROAD-007? If yes: which minimum data and staleness rules, which rate
algorithm, how Road shows the estimate apart from facts, which requirement
wording must change, and what an implementation card would have to prove.

## Evidence

- **Core C2** allows a value that "deterministic logic derives safely"; it
  forbids inference by a model or from locale alone (`../../core.md`).
- **The data model already names the rate.** The source-of-truth matrix lists
  "latest reading, mileage rate" as derived from odometer reading history, and
  REQ-DOMAIN-001 says a mileage rate is projected from that history
  (`../../requirements/domain-model.md`). A rate is therefore a planned
  derivation, not a new fact.
- **REQ-ROAD-007** forbids converting time to mileage or mileage to time
  "and no explicit supported projection model"; the contract section "Mixed time
  and mileage" says the same. The requirement anticipates a model; none exists.
- **ADR 0008** places and labels each milestone by one dimension and orders the
  lane by a hidden key in horizon units (remaining km / 5,000 or days / 183).
  It rejected an average daily rate until an explicit model and owner decision
  exist. Mileage is stale after 90 days (`MaintenanceRules.mileageStaleAfter`,
  `Pitstop/Domain/Maintenance/MaintenanceEngine.swift`).
- **ADR 0010** rejected estimating *current* mileage from past readings. This
  card estimates a *date*, and only while the current mileage is known.
- **Code facts.** `MaintenanceContext` takes the newest observation from
  odometer readings and completions saved with mileage; `remainingKm` exists
  only when that observation is current (`MaintenanceEngine.swift`).
  `RoadMilestone` carries `remainingKm`, `remainingDays`, `anchorKm`,
  `anchorDate`; `RoadContext` has no reading history today
  (`Pitstop/Domain/Road/RoadProjection.swift`). Readings keep a unit and
  convert with `valueInKilometers` (`Pitstop/Domain/Vehicle/Vehicle.swift`).
  `DomainCommand` has no command to correct or delete a reading
  (`Pitstop/Domain/Capture/DomainCommands.swift`).

## Options

| Option | What Road shows | C2 / REQ-ROAD-007 | Verdict |
|---|---|---|---|
| E0. No estimate (today) | "in 4,940 km" only | Holds | Baseline |
| E1. Labelled date range as an annotation | "in 4,940 km" plus "Estimate: Dec 10 – Jan 11" | Holds if the range is derived, labelled, never stored, and not used to place or order the milestone; needs wording change | **Recommended** |
| E2. Estimate also orders the lane | As E1, and the milestone moves among date milestones by its estimated date | Changes ADR 0008 ordering and clustering; a wrong rate reorders the Road | Later, only with evidence |
| E3. Single estimated date | "around Dec 21" | False precision; hides the spread | Rejected |
| E4. Mean of all consecutive rates | As E1 | One typo or road trip dominates | Rejected |

## Recommendation

Conditional **go** for E1 once the owner accepts the REQ-ROAD-007 change below.

### Eligibility (all must hold, otherwise no estimate is shown)

1. The milestone is placed by distance with a known `remainingKm > 0`
   (not due, not overdue, not waiting for mileage).
2. Observations: odometer readings and completions saved with mileage, from
   the last 365 days, one per calendar day (the higher value wins a day).
3. At least 3 observations spanning at least 60 days.
4. The newest observation is at most 90 days old, the same staleness rule as
   Service and Road. A stale car shows no estimate because it has no
   `remainingKm` either.
5. At least 2 usable pairs remain after rejection (below).
6. The late bound is at most 2 × the early bound in days, and the early bound
   is within 730 days. A wider or farther range says nothing useful.

### Algorithm (pure, deterministic, computed on read, never stored)

1. Sort observations by date. Build consecutive pairs; merge a pair shorter
   than 7 days into the next one, so two readings a day apart cannot produce an
   extreme rate.
2. Reject a pair whose distance is negative (a typo or unit mix-up) or whose
   rate exceeds 1,500 km/day (implausible).
3. Typical rate: median of pair rates; reject pairs whose rate differs from
   the median by more than `max(3 × 1.4826 × MAD, 0.25 × median)`, then take
   the median again. The floor keeps identical rates (MAD 0) from rejecting
   everything.
4. Overall rate: (newest km − oldest km) / days between them, over accepted
   observations. It keeps real trips that the typical rate discards.
5. Range from the newest observation date `t0`:
   early = `t0 + remainingKm / max(typical, overall)`,
   late = `t0 + remainingKm / min(typical, overall)`, whole days.
6. If the operation also has a time rule, the late bound is capped at the time
   anchor, because the time rule will decide by then anyway.

### Worked example (fictional car)

| Date | Reading | Days | km | Rate km/day |
|---|---:|---:|---:|---:|
| 2026-05-01 | 40,000 | | | |
| 2026-05-31 | 41,300 | 30 | 1,300 | 43.3 |
| 2026-06-30 | 42,500 (oil done) | 30 | 1,200 | 40.0 |
| 2026-07-15 | 45,100 (road trip) | 15 | 2,600 | 173.3 |
| 2026-08-14 | 46,300 | 30 | 1,200 | 40.0 |
| 2026-09-13 | 47,560 | 30 | 1,260 | 42.0 |

- Today 2026-09-22: 6 observations over 135 days, newest 9 days old: eligible.
- Median of five rates 42.0; MAD 2.0; threshold `max(8.9, 10.5)` = 10.5; the
  173.3 pair is rejected. Typical rate: median of 40.0, 40.0, 42.0, 43.3 = 41.0.
- Overall rate: 7,560 km / 135 days = 56.0 km/day.
- Oil every 10,000 km or 12 months, done at 42,500 on 2026-06-30: anchor
  52,500 km, `remainingKm` 4,940 at 47,560.
- Early: 4,940 / 56.0 = 88 days → 2026-12-10. Late: 4,940 / 41.0 = 120 days →
  2027-01-11. The time anchor 2027-06-30 is later, so no cap. Ratio 1.36:
  shown.
- Road: "in 4,940 km" as the fact, with "Estimate: Dec 10 – Jan 11" below.

### Display

- The fact stays the primary label (REQ-ROAD-007 dimension rule). The estimate
  is a secondary line with the word "Estimate" (localized), secondary colour,
  never amber and never a state.
- Month granularity when the range crosses more than 45 days ("Estimate:
  December – January"); day granularity otherwise.
- Placement, ordering, clustering and the horizon ignore the estimate
  (ADR 0008 unchanged). Car Board inherits it only through the Road tile.
- VoiceOver reads "Estimated between December 10 and January 11, from your
  mileage readings". The semantic summary (REQ-ROAD-015) does not mention
  estimates.
- Service is out of scope for the first slice; the owner decides whether it
  shows the same line.

### Proposed requirement changes (proposals only)

REQ-ROAD-007, replacing the Then line:

> Then each milestone is placed, ordered and labelled by its own dimension;
> time is not converted to mileage or mileage to time except in the labelled
> date estimate of REQ-ROAD-022; and current mileage is never invented

New REQ-ROAD-022 — A distance milestone may carry a labelled date estimate:

> Given a distance-placed milestone with known remaining kilometres and an
> eligible reading history (REQ-ROAD-023)
> When the Road projection is computed
> Then the milestone carries an estimated date range derived from the reading
> history, labelled as an estimate, and its placement, order and state are the
> same as without it

New REQ-ROAD-023 — No estimate without enough recent readings:

> Given fewer than 3 observations in the last 365 days, a span under 60 days,
> a newest observation older than 90 days, fewer than 2 usable pairs, or a
> range wider than twice its early bound
> When the Road projection is computed
> Then the milestone carries no estimate and nothing else changes

## Rejected alternatives

- **Estimating current mileage** to fill stale or unknown mileage: invents a
  fact (ADR 0010, REQ-DOMAIN-002).
- **A model or locale-based typical mileage** ("average driver: 15,000 km a
  year"): C2 forbids both.
- **Storing the estimate or the rate:** it goes stale and becomes a second
  source of truth, like persisted status (ADR 0010).
- **Linear regression over all points:** needs more readings than most owners
  enter and is as sensitive to typos as the mean; the median is enough for the
  sparse data expected.
- **Asking for readings to feed the estimate:** a Pit question needs
  measurable value (C3); the existing current-mileage question stays the only
  one.

## Risks

- **Read as a promise.** Mitigated by range, label, secondary styling and the
  km fact staying primary.
- **Service-day bias.** Owners may enter readings only at services; spans
  still pass 60 days, but a pattern change (new commute) lags. The range and the
  365-day window limit the damage.
- **Uncorrectable typos.** No reading correction command exists; negative
  pairs and the outlier rule absorb one bad value, but a typo that inflates the
  newest reading also shifts `remainingKm`. A reading correction card is a
  natural companion, not a prerequisite.
- **Units.** Readings in miles convert through `valueInKilometers`; a reading
  entered in the wrong unit shows as a rejected pair.
- **Time zones.** Day bucketing uses the owner's calendar, as ADR 0032 does
  for planned dates.

## Implementation impact

- New pure domain type, for example `MileageRateEstimator` in
  `Pitstop/Domain/Road/`, taking observations, `now` and a calendar, returning
  an optional rate pair.
- `RoadContext` gains the observation list (or a precomputed rate);
  `RoadMilestone` gains an optional estimated date range. `RoadProjector`
  ordering and clustering are untouched.
- Road view and Car Board Road tile render the secondary line; String Catalog
  entries in en, ru, uk.
- No schema change, no command, no capture change.

## Follow-up card proposal

**ROAD-EST-002 Labelled date estimate on Road distance milestones**
(implementation, about 2 days; depends on the owner accepting the requirement
changes above; go when accepted, no-go otherwise).

Acceptance:
- The worked example yields exactly 2026-12-10 to 2027-01-11 (unit test).
- Each ineligibility rule yields no estimate: 2 readings; 50-day span; newest
  reading 91 days old; only one usable pair; ratio above 2; due milestone;
  waiting-for-mileage milestone (REQ-ROAD-023).
- Placement, order, clustering and horizon of every fixture are identical with
  and without estimates (REQ-ROAD-007, REQ-ROAD-022).
- A negative pair and an implausible rate are rejected; identical rates do not
  reject each other; a mixed km/miles history converts before rating.
- The late bound is capped by a time anchor.
- Same inputs give the same output (REQ-ROAD-003).
- UI shows the "Estimate" line only when the projection carries one, with
  VoiceOver wording; checked on the simulator with DEBUG demo data extended by
  fictional readings.

Test plan: `PitstopTests/Road/MileageRateEstimatorTests.swift` (algorithm and
eligibility), additions to the Road projector tests (invariance),
view-model tests for label text, `just verify`, one simulator smoke.

## Owner decisions

1. Are estimates wanted at all? If yes, accept the REQ-ROAD-007 wording and
   REQ-ROAD-022, 023.
2. Constants: 3 readings, 60 days, 365-day window, ratio 2, 730-day limit.
3. Road only, or also the Service row?
4. Whether a reading correction command is scheduled alongside.
