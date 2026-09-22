# Labelled Date Estimate on Road Distance Milestones

**Status:** Accepted (owner decision, 2026-09-22): estimates are wanted, the
REQ-ROAD-007 wording and REQ-ROAD-022/023 are approved, the constants below are
approved, and Road is the only surface in this slice\
**Task:** ROAD-EST-002\
**Builds on:** [`0008-road-projection-rules.md`](0008-road-projection-rules.md)
(one lane, one dimension per milestone, ordering key, staleness),
[`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md)
(no estimated current mileage, no stored status),
[`0032-planned-dated-events.md`](0032-planned-dated-events.md)
(day bucketing in the owner's calendar)\
**Source:** [ROAD-EST-001](../planning/investigations/road-est-001-mileage-rate-estimate.md),
option E1\
**Contracts:** [`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md)
(REQ-ROAD-007, REQ-ROAD-022, REQ-ROAD-023, approved 2026-09-22); core C2
(a value deterministic logic derives safely, never one a model or a locale
invents)

## Context

Road places a maintenance milestone by the dimension that decided its status
and labels it in that dimension: "in 4,940 km" (ADR 0008). The owner cannot
tell whether that is next month or next winter. ADR 0008 rejected an average
daily rate at the time because REQ-ROAD-007 requires "an explicit supported
projection model" first, and none existed.

The data for one does: the source-of-truth matrix already lists a mileage rate
as derived from reading history (REQ-DOMAIN-001), and the engine already reads
odometer readings and completions saved with mileage as one series of mileage
observations (REQ-BOARD-026).

## Decision

A distance milestone may carry a **labelled date range**, derived when Road is
projected and never stored.

1. **Annotation only.** The estimate never places, orders or clusters a
   milestone and never changes its state. ADR 0008 is unchanged: the ordering
   key stays remaining km / 5,000 or days / 183. `RoadProjector` attaches the
   estimate to a milestone that is already complete, and nothing downstream of
   that reads it.
2. **Derived on read.** `MileageRateEstimator` is a pure value type with an
   injected `now` and calendar. No schema change, no command, no capture change,
   nothing persisted: a stored rate would become a second source of truth that
   goes stale, the mistake ADR 0010 avoided for status.
3. **Eligibility.** One observation per calendar day, the higher value winning
   the day; at least 3 of them in the last 365 days spanning at least 60 days;
   the newest at most 90 days old (`mileageStaleAfter`, the same rule Service
   and Road already use); remaining kilometres above 0. Observation count is not
   enough on its own: after the 7-day merge and the rejections below, at least
   2 usable pairs must remain, so readings on days 0, 3 and 60 leave one pair
   and no estimate.
4. **Robust rate.** Consecutive pairs, a pair shorter than 7 days merged into
   the next one; pairs with a negative distance or above 1,500 km/day dropped;
   median of the pair rates; pairs beyond
   `max(3 × 1.4826 × MAD, 0.25 × median)` rejected; median again. The relative
   floor keeps a history of identical rates from rejecting itself.
5. **A range, not a date.** The overall first-to-last rate is computed too; the
   range runs from the faster rate to the slower one, counted from the day of
   the newest observation. Nothing is shown when the late bound is more than
   twice the early one, or when either bound is more than 730 days away
   (`maximumEstimateDaysAhead`): the ratio alone would allow a late bound four years
   out.
6. **Caps.** The late bound is capped at the operation's time anchor, because
   the time rule decides by then anyway; an estimate that would end before
   today is not shown at all, because a rate read from a three-week-old
   observation must not point backwards.
7. **Surface.** The kilometre fact stays the primary label. The estimate is a
   secondary tertiary-coloured line, "Estimate: Mar 2 – Mar 28", by month when
   the range crosses more than 45 days ("Estimate: December 2026 – March 2027"),
   in en, ru and uk with locale-aware date formatting. Each bound is formatted
   on its own, and both carry their year as soon as either bound falls outside
   the current calendar year, so neither "November – November" a year apart nor
   "Mar 8 – Mar 9" two years out can read as the months just ahead; only a range
   of a single day prints one date. VoiceOver reads "Estimated between
   December 10, 2026 and January 11, 2027, from your mileage readings", and a
   single-day range is spoken as "Estimated around March 8, 2028" rather than as
   a range between one date and itself. The semantic summary (REQ-ROAD-015) says
   nothing about estimates.

Constants live in `MileageRateRules` next to `RoadRules`, so a beta can move
them without touching the projection.

## Worked example (fictional car)

Readings 40,000 (2026-05-01), 41,300 (05-31), 45,100 (07-15, road trip),
46,300 (08-14), 47,560 (09-13), and oil done at 42,500 on 06-30. On 2026-09-22
the typical rate is 41.0 km/day (the 173 km/day trip pair is rejected), the
overall rate 56.0 km/day, and 4,940 km remain. The range is 2026-12-10 to
2027-01-11, so Road shows "in 4,940 km" and, under it,
"Estimate: Dec 10, 2026 – Jan 11, 2027": the late bound is in the next year,
so both bounds carry one.

## Consequences

- Road answers "roughly when?" for the first time without inventing a fact, and
  a car with sparse readings simply shows what it showed before.
- Car Board's compact lane has no room for a second caption line, so the tile
  keeps the fact only; the Road screen shows the estimate in the lane and in
  the list.
- The label code is one place (`RoadEstimateLine`, `RoadMilestone.distanceText`),
  so MNT-VR-002 can add its "from dashboard" provenance suffix to the fact line
  and reach every Road surface at once.
- A wrong newest reading shifts both the remaining kilometres and the estimate.
  No reading correction command exists yet; the negative-pair and outlier rules
  absorb one bad value in the middle of the history, not at its end.

## Rejected alternatives

- **Ordering the lane by the estimate** (E2 in the record): a wrong rate would
  reorder the Road itself, and clustering would depend on a guess. Later, only
  with beta evidence.
- **A single estimated date** ("around Dec 21"): false precision that hides the
  spread the two rates actually show.
- **Mean of all pair rates** (E4): one typo or one road trip dominates it; the
  median plus MAD rejection is why the trip pair changes nothing.
- **Linear regression over all readings:** needs more points than owners enter
  and is as sensitive to a typo as the mean.
- **Estimating current mileage** to fill a stale or missing observation: invents
  a fact (ADR 0010, REQ-DOMAIN-002). A stale car has no remaining kilometres and
  therefore no estimate either.
- **A model or a locale-based typical mileage** ("15,000 km a year"): core C2
  forbids both.
- **An interval date format** (`Date.IntervalFormatStyle`): it prints a year for
  every field combination once the range crosses one and gives no control over
  it. The bounds are formatted separately and joined with an en dash, and the
  year rule is the app's own.
- **Leaving the year out entirely** (the illustrative label of the ROAD-EST-001
  record): independent review showed it reads wrong for a wide range, where
  November 2027 to November 2028 collapses to "November" and April 2028 to
  August 2029 reads as "April – August".
- **Comparing the two bounds only to each other** for the year rule: a range
  wholly inside a future year then prints no year at all, so March 2028 reads as
  the coming March. The comparison is against today instead.

## Follow-ups

- MNT-VR-002 shares the Road label code for its "from dashboard" suffix.
- Whether the Service row shows the same line is an open product question; this
  slice is Road only.
- A reading correction command remains a natural companion, not a prerequisite.
