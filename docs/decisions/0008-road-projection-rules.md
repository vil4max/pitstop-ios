# Road Projection Rules (INV-ROAD-001…004)

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-20); owner review pending. These are product hypotheses, to be
revisited with beta evidence.\
**Tasks:** INV-ROAD-001, INV-ROAD-002, INV-ROAD-003, INV-ROAD-004\
**Contract:** [`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md)

No usage data exists, so each question was decided by checking the candidate
rules against the contract's test-first scenarios and failure criteria. The
comparison tables are the evidence; the numbers are constants in one place
(`RoadRules`) so they can change without touching the projection.

## INV-ROAD-001 — Horizon and spacing

| Candidate | Sparse car (1 milestone in 14 months) | Dense car (9 in 6 months) | Verdict |
|---|---|---|---|
| Fixed six months | Empty road although a milestone is known; violates REQ-ROAD-008 | Shows all 9; crowded | Rejected |
| Nearest N | Fine | Fine, but "N" hides whether the next one is next week or next year | Rejected alone |
| Adaptive bounded | Horizon stretches to the nearest milestone | Horizon stays at the default and the count is capped | **Chosen** |

Rule:

- Default horizon: 6 months and 5,000 km.
- The initial viewport shows at most 4 slots. A slot is a milestone or a
  cluster.
- Overdue and due milestones always occupy the first slots.
- If no milestone falls inside the default horizon, the horizon extends to the
  nearest known milestone and the projection reports `extendedToNearest`,
  so the UI can say "nothing soon; next is …" instead of showing empty road.
- Later milestones exist in the projection and are reached by scrolling.
- Spacing is ordinal, not metric: slots are evenly spaced in order of
  proximity. A literal scale either crowds near milestones or pushes far ones
  off screen, and would imply a precision the data does not have.

## INV-ROAD-002 — Mixed time and mileage

One lane. Each milestone is placed and labelled by one dimension: the one that
decided its maintenance status, or the date for a planned event. The label shows
that dimension ("in 1,200 km" or "20 days left"), never a converted value, so
REQ-ROAD-007 holds.

The lane is ordered by an **ordering key in horizon units**: remaining km /
5,000 or remaining days / 183. The key is never displayed. It uses the pairing
the horizon already states ("six months or 5,000 km are equally far for this
product"), and nothing else is derived from it. Nearness alone orders the lane:
due and overdue have a non-positive key and therefore lead, and on an exact tie
the more urgent state comes first. A milestone is inside the default viewport
when its key is at most 1. State does not move a milestone forward: a
transmission service that is "approaching" with 8,000 km left is still farther
than an oil change 5,500 km away.

An earlier version of this ADR ordered the lane by the remaining share of each
milestone's own interval. Independent review showed it is wrong: a transmission
service 12,000 km away (20% of 60,000) sorted ahead of an oil change 3,000 km
away (30% of 10,000), and the default viewport then hid the oil change. Share
decides *status* in the engine; it does not measure *nearness*.

- Mileage is **unknown** with no observation and **stale** when the newest one
  is older than 90 days. A milestone with a date rule keeps its place through
  the date and carries the mileage dependency as a flag (REQ-ROAD-005). A
  mileage-only milestone that cannot be evaluated, including one whose
  completion was saved without mileage, is returned in `waitingForMileage` with
  its reason and is not placed (REQ-ROAD-006). When only such milestones exist
  the horizon is `waitingForMileage`, not "no known milestones".
- A planned date that has passed stays on the road as due for 14 days and then
  leaves it; nothing else owns an expired plan, and it must not linger forever.

Rejected: two parallel lanes (time above, mileage below). It doubles the
vertical cost of a compact tile and makes a distance-or-time operation appear
twice.

Rejected: estimating mileage from an average daily rate. That is the "explicit
supported projection model" the contract requires first; it needs several
readings and an owner decision, and belongs to MNT-INT-001.

## INV-ROAD-003 — Clustering

Two milestones cluster when both are placed by distance within 1,500 km of each
other, or both by date within 21 days (inclusive). A cluster takes one slot,
is led by its nearest member, and lists its members nearest first. Milestones
placed by different dimensions never cluster, because how far apart a date and
a mileage are is unknown; this holds even when a date-decided operation also
has a mileage anchor nearby. Work that is due or overdue is never merged with
milestones that are still ahead, so it always leads its own slot.

Clustering runs per dimension, nearest first, comparing each milestone with the
first member of the open cluster. It therefore does not depend on what sorts in
between in the other dimension, it is deterministic, and a chain of close
milestones cannot grow without bound (REQ-ROAD-003).

This is visual only. It does not read or write Service Planner grouping, and
it never changes an operation's anchor (REQ-MAINT-007).

## INV-ROAD-004 — Return to current position

Native scroll position, no custom gesture:

- Road is a horizontal `ScrollView` bound with `scrollPosition(id:)`; the car
  slot has a stable ID.
- When the car slot is scrolled out of view, a "Now" button appears at the
  leading edge and scrolls back to it.
- Road resets to the car slot whenever the screen appears again.

Rejected: automatic snap-back after a delay (moves content under the user's
finger) and a custom pull gesture (the contract forbids it without evidence).
With Reduce Motion the scroll is not animated (REQ-ROAD-014).

## Past

The projection returns a count and the date of the latest past event as one
compact "look back" marker behind the car. It never returns individual past
events; History owns them (REQ-ROAD-010).

## Consequences

- Eligibility, ordering, clustering, horizon, and the semantic summary are all
  computed in the domain (CB-006). The UI renders slots in order and decides
  nothing (REQ-ROAD-004).
- The constants above are hypotheses. Evidence to collect later: how often
  Road opens with `beyondDefaultHorizon`, how often clusters are expanded, and
  how often "Now" is used.
