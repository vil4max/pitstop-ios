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
  nearest known milestone and the projection marks it `beyondDefaultHorizon`,
  so the UI can say "nothing soon; next is …" instead of showing empty road.
- Later milestones exist in the projection and are reached by scrolling.
- Spacing is ordinal, not metric: slots are evenly spaced in order of
  proximity. A literal scale either crowds near milestones or pushes far ones
  off screen, and would imply a precision the data does not have.

## INV-ROAD-002 — Mixed time and mileage

One lane, ordered by proximity, where proximity is a fraction of the
milestone's own interval that remains (`remaining / interval`), computed
separately per dimension. Fractions are comparable without converting months to
kilometres, so REQ-ROAD-007 holds.

- A distance-or-time policy uses the dimension with the smaller remaining
  fraction; the label shows that dimension ("in 1,200 km" or "in 3 weeks"),
  never a converted value.
- A milestone with no interval (insurance expiry, planned event) uses days
  remaining over the default horizon.
- Mileage is **unknown** when there is no reading, and **stale** when the
  latest reading is older than 90 days. In both cases a mileage-dependent
  milestone keeps its place only through its time dimension if it has one;
  otherwise it is listed after all placed milestones with dependency
  `mileageUnknown` or `mileageStale`, and no remaining distance is shown
  (REQ-ROAD-005, REQ-ROAD-006). Stale mileage still shows "as of" its date.

Rejected: two parallel lanes (time above, mileage below). It doubles the
vertical cost of a compact tile and makes a distance-or-time operation appear
twice.

Rejected: estimating mileage from an average daily rate. That is the "explicit
supported projection model" the contract requires first; it needs several
readings and an owner decision, and belongs to MNT-INT-001.

## INV-ROAD-003 — Clustering

Two milestones cluster when both are distance-anchored within 1,500 km of each
other, or both are date-anchored within 21 days. A cluster takes one slot,
is labelled with its earliest member plus a count, and lists its members in
proximity order. Mixed-dimension milestones never cluster with each other
because their distance apart is unknown.

Clustering is single-pass over the proximity-ordered list, comparing each
milestone with the first member of the current cluster, so the result is
deterministic and a chain of close milestones cannot grow without bound
(REQ-ROAD-003, REQ-ROAD-013).

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
