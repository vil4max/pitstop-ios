# Maintenance Anchor Closure (ADR 0001 open questions)

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** DOM-004\
**Contracts:** [`0001-maintenance-anchors.md`](0001-maintenance-anchors.md),
[`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md),
[`../requirements/domain-model.md`](../requirements/domain-model.md), core C2, C5 and P3,
[`0007-persistence.md`](0007-persistence.md),
[`0008-road-projection-rules.md`](0008-road-projection-rules.md),
[`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md),
[`0016-question-registry.md`](0016-question-registry.md),
[`0017-first-question-current-mileage.md`](0017-first-question-current-mileage.md)

## Context

ADR 0001 is still `Proposed`. It was written against the `legacy/spike`
codebase (seeded future visits, a parallel oil engine, localized titles taking
part in task identity) and leaves several points open by its own wording:
"accepted by default", "accepted direction", "a temporary adapter",
"migration timing remains gated", "a future explicit policy type", and a Costs
list of work that must exist before the decisions hold. The DOM-004 card
requires them to be closed before Phase 7 maintenance work, and the delivery
brief (`../tasks/full-backlog-delivery.md`, "Order") schedules DOM-004 before
MNT-INT-001.

Since then the greenfield `main` has implemented the engine, the planner, the
Service surface, and persistence (ADR 0007, 0010), and Pit asks for mileage
when it blocks distance rules (ADR 0016–0018). This ADR maps every open point
of ADR 0001 to one of three states:

- **Decided earlier:** an accepted ADR and the code or tests already settle it.
- **Decided here:** settled now by this ADR, consistent with the implemented
  engine; tests carry the `ADR-0020` tag.
- **Owner question:** needs product policy, legal judgement, or manufacturer
  data; a recommended answer is given, nothing is implemented on the guess.

The ADR edits no requirement text and no core text. One requirement change is
proposed below for owner approval.

## Question map

| ID | Open point (ADR 0001 source) | State |
|---|---|---|
| Q1 | Operations own their lifecycle; oil is not a special engine (Decision 1, Consequences) | Decided earlier |
| Q2 | An anchor is a planning horizon, not a health threshold (Decision 2) | Decided earlier |
| Q3 | Early completion resets from actual facts; fixed grid needs "a future explicit policy type" (Decision 3) | Reset: decided earlier. Fixed grid: decided here |
| Q4 | Grouping is deterministic and never moves a cycle (Decisions 4, 5) | Decided earlier |
| Q5 | "Planner requires explicit grouping rules" (Costs); eligibility and procedure relationships as inputs | Windows: decided earlier. Eligibility: decided here |
| Q6 | Official recommendation and user policy are separate, provenance kept (Decision 6) | Separation: decided earlier. Recommendation data: owner question B |
| Q7 | Status only from effective policy and confirmed facts; AI cannot set it (Decision 7) | Decided earlier |
| Q8 | Missing baseline is unknown, no implicit zero (Decision 8) | Decided earlier |
| Q9 | Stable IDs replace title identity; "current title mapping is a temporary adapter" (Decision 9) | IDs: decided earlier, pinned here. Adapter: decided here |
| Q10 | Seeded visits stop being the schedule; "migration timing remains gated" (Decision 10) | Decided here; legacy import is owner question D |
| Q11 | "Operation identity catalog is required" (Costs) | Decided here |
| Q12 | Procedure composition with sourced required components (Additional decision) | Owner question B |
| Q13 | Service Plan (accepted scope) separate from Service Visit (history) (Additional decision) | Separation: decided earlier. Plan and multi-operation visit scope: owner question C |
| Q14 | Procedure applicability and provenance "becomes a data problem" (Costs) | Owner question B |
| Q15 | ADR 0001 itself is `Proposed` | Owner question A |

## Decided earlier (evidence)

**Q1 — independent operations.** The engine keeps one latest completion per
operation and one state per effective policy
(`Pitstop/Domain/Maintenance/MaintenanceEngine.swift:100-111`); there is no
oil-specific path, and engine oil is one catalog entry among seven
(`Pitstop/Domain/Maintenance/Maintenance.swift:18-29`). Tests:
`MaintenanceEngineTests.cyclesAreIndependent` (REQ-MAINT-004,
`PitstopTests/Maintenance/MaintenanceEngineTests.swift:110`),
`ServicePlannerTests.partialVisitKeepsSkippedOperationDue` (REQ-MAINT-014,
`PitstopTests/Maintenance/ServicePlannerTests.swift:78`).

**Q2 — anchor wording.** ADR 0010 "What the user does on the Service surface":
due is amber, there is no danger colour and no health score. The copy speaks
of a "planned point" and a "planning horizon, not a diagnosis"
(`service.track.footer`, `service.progress.reached`, `service.progress.overKm %lld`
in `Pitstop/Resources/Localizations/Localizable.xcstrings`). Copy has no
automated test; it is covered by review.

**Q3 — reset from actual completion.** ADR 0010 "Anchors come from actual
completions": `anchorKm = completion mileage + interval`, and the time anchor
is the completion date plus the interval
(`MaintenanceEngine.swift:130-132`, `:147-150`). Tests:
`earlyCompletionRebaselines` (REQ-MAINT-018, `MaintenanceEngineTests.swift:74`),
`ownerIntervalDerivesAnchor` (REQ-MAINT-003, `:66`), and the new
`lateCompletionRebaselines` (ADR-0020, `:90`): a late completion also moves the
anchor, so no grid is hidden in the engine.

**Q4 — grouping.** ADR 0010 "Planner": the scope is derived on demand, never
stored, and cannot change an anchor (`Pitstop/Domain/Maintenance/ServicePlanner.swift:3-4`,
`:25-64`). Road's milestone clustering is visual only (ADR 0008). Tests:
REQ-MAINT-005 `dueOperationsShareOneScope` (`ServicePlannerTests.swift:37`),
REQ-MAINT-006 `dueNearbyJoinsScope` (`:42`) and `nearbyIsMeasuredFromTheVisit`
(`:49`), REQ-MAINT-007 `groupingKeepsAnchor` (`:57`), REQ-MAINT-013
`plannerIsDeterministic` (`:73`).

**Q5 — grouping windows.** ADR 0010 "Planner": 2,000 km or 45 days around the
visit point, unknown never grouped, the visit point is "now" when something is
due (`MaintenanceEngine.swift:8-11`, `ServicePlanner.swift:29-62`). Tests: as in
Q4, plus `approachingVisitUsesDecidingDimension` (ADR-0010,
`ServicePlannerTests.swift:98`).

**Q6 — policy separation.** `PolicySource` with precedence user custom over
vehicle condition over recommendation, and `effective` picks one policy per
operation (`Maintenance.swift:32-76`). ADR 0007 keys stored policy rows by
vehicle, operation and source, so a custom policy never overwrites a
recommendation. Tests: REQ-DOMAIN-006 `customPolicyIsEffective`
(`MaintenanceEngineTests.swift:215`) and `customPolicyReplacesEffectivePolicy`
(`PitstopTests/Persistence/SwiftDataCarMemoryStoreTests.swift:140`).

**Q7 — status authority.** Status is computed on read and never persisted
(ADR 0010, rejected alternatives). `MaintenanceOperationState` has no public
initializer: only code inside the app module can construct it, and production
code gets it from the engine (`MaintenanceEngine.swift:71-95`); tests build
fixtures directly.
Capture can only propose a completion or a policy, both behind confirmation
(`Pitstop/Domain/Capture/ConfirmationPolicy.swift:52`,
`Pitstop/Domain/Capture/DomainCommandMapper.swift:40-56`). Tests: REQ-CAPTURE-016
(`PitstopTests/Capture/ConfirmationPolicyTests.swift:43`), REQ-CAPTURE-018
(`:139`), REQ-MAINT-022 `engineIsDeterministic` (`MaintenanceEngineTests.swift:207`).

**Q8 — unknown baseline.** No completion gives `unknown` and no numbers; a
completion without mileage cannot anchor a distance rule; stale or missing
mileage blocks the distance rule with a named reason (ADR 0010 "Unknown is a
state, not a zero"; `MaintenanceEngine.swift:119-124`, `:133-142`). Pit asks for
the current mileage only when that block matters (ADR 0017). Tests:
REQ-MAINT-016 `unknownBaseline` (`MaintenanceEngineTests.swift:46`) and
`completionWithoutMileage` (`:171`), `unknownIsNotGrouped`
(`ServicePlannerTests.swift:62`), REQ-MAINT-017 (`PitstopTests/Maintenance/ServiceViewModelTests.swift:22`).

**Q13 — plan is not visit.** The suggested scope is not stored (Q4), and a
confirmed completion does not insert a History event (ADR 0007, rejected
alternatives). Test: ADR-0007 `completionIsStoredForConfirmedOperationOnly`
(`SwiftDataCarMemoryStoreTests.swift:168`).

## Decided here

### Q3 — no fixed-grid policy type in the first slice

Every policy anchors on the actual completion, early or late. No fixed-grid
policy type is added now.

- **Rationale:** a fixed grid only matters when an official schedule defines
  milestones (for example "every 15,000 km from zero"), and no verified
  recommendation exists in the app (ADR 0010: none is seeded; owner question B).
  A type with no source would be a dead abstraction and a second anchor rule
  to test.
- **Constraint when it is added:** an explicit per-policy anchoring field whose
  default is completion-based, carried by a sourced recommendation or chosen by
  the owner; never inferred from wording or by a model (core C2, P3). A policy
  without the field keeps today's behaviour.
- **Consistency:** matches `MaintenanceEngine.swift:130-150`; pinned by
  `lateCompletionRebaselines` (ADR-0020).
- **Rejected:** a global "grid mode" switch (ADR 0001 already rejects global
  modes); snapping a late completion to the next grid point (would move a cycle
  on facts the user did not confirm).

### Q5 — every tracked operation is equally eligible for grouping

The planner treats every operation with a known status as eligible, with the
same windows. No per-operation eligibility and no procedure relationships are
modelled.

- **Rationale:** eligibility and relationships are procedure knowledge, which
  needs verified data (owner question B). The contract lets the planner use
  explicit tolerances until "a future knowledge source" provides operation
  semantics.
- **Constraint:** when a source adds eligibility, it narrows grouping only; it
  never adds an operation that is outside the windows and never changes an
  anchor (REQ-MAINT-007).
- **Rejected:** hand-written eligibility per catalog entry (invented truth).

### Q9 — no title adapter; stored IDs are frozen

`MaintenanceOperationID` is a string-backed identity
(`Maintenance.swift:3-30`), stored as its raw value
(`Pitstop/Infrastructure/Persistence/PitstopSchemaV1.swift:104-145`,
`Pitstop/Infrastructure/Persistence/RecordMapping.swift:111`, `:120`, `:133`,
`:145`). Localized titles are presentation only and an unknown ID is shown
verbatim (`Pitstop/Features/History/HistoryView.swift:212-226`). The
greenfield app never used titles as identity, so the "temporary adapter" from
the legacy audit is not built.

- **Constraint:** a raw value in the catalog is never renamed; a new operation
  gets a new ID. An ID outside the catalog is valid identity and survives
  storage and the engine.
- **Tests:** `operationIDsAreStable` (ADR-0020,
  `MaintenanceEngineTests.swift:102`) pins the catalog's raw values;
  `uncataloguedOperationKeepsIdentity` (ADR-0020,
  `SwiftDataCarMemoryStoreTests.swift:396`) stores a policy and a completion for
  an uncatalogued ID, reopens the store, and gets its state from the engine.
- **Rejected:** mapping legacy titles to IDs "just in case" (no reader for it;
  see owner question D).
- **Note:** `Localizable.xcstrings` still holds legacy `service.task.*`,
  `service.visit*`, `service.oil*` and `service.reopenVisit*` strings that no
  Swift source references. They are not identity; removing them is a separate
  cleanup.

### Q10 — seeded visits are gone; no migration is scheduled

Greenfield `main` has no future-visit entity, no seed importer, and no pending
template visits. The DEBUG-only demo data writes policies, completions and
readings through domain commands into an in-memory store
(`Pitstop/App/DemoData.swift:1-12`). ADR 0007 rejected reusing the legacy
models, so nothing reads a legacy store. Decision 10 is therefore implemented,
and its "migration timing" has nothing left to migrate unless the owner wants
legacy data imported (owner question D).

### Q11 — the catalog is code-owned and grows by ID

The catalog is the list of operations the app can name
(`Maintenance.swift:26-29`): engine oil, DSG, AWD coupling, brake fluid, cabin
filter, air filter, spark plugs. Adding an operation means a new stable ID, a
localized title, and an update to the pinning test. Free-text user-defined
operations are not added: no requirement asks for them, and they would need
their own identity and merge rules. MNT-INT-001 may propose additions from
user evidence.

### Status of ADR 0001 for Phase 7

With the points above, MNT-INT-001 may rely on ADR 0001's decisions 1–10 as
implemented. What remains open is data and scope (owner questions B and C),
which is what Phase 7 investigates.

## Owner questions

**A. Promote ADR 0001 from `Proposed` to `Accepted`?**
Recommended: yes, with Decision 10's migration clause read through Q10 above.
Consequence: Phase 7 builds on it as settled; its review triggers (five-car
beta, schedule normalization, grouping confusion) stay. If no, the engine keeps
working, but every Phase 7 decision has to re-argue the same ten points.

**B. Where do verified recommendations and procedure compositions come from?**
This covers Q6 provenance, Q12 and Q14: manufacturer, market, model and
generation, powertrain, source revision; licensing to redistribute the data;
who verifies it.
Recommended: none in the first slice; keep owner cadence as the only policy
source. MNT-INT-001 evaluates one source for one fictional fixture car and
records its provenance fields and licence before any data enters the app. Real
vehicle data stays out of this public repository (AGENTS.md).
Consequence: REQ-MAINT-008, 010, 019–021 and REQ-DOMAIN-004, 005 stay
satisfied vacuously (nothing is preselected, nothing appears under
`Consider`), and fixed grids stay out (Q3).

**C. Scope and order of Service Plan and multi-operation visit recording?**
Recommended: build multi-operation visit recording first: one `service`
History event plus completions only for the checked operations, linked through
`sourceEventID` (REQ-MAINT-014, 015, REQ-DOMAIN-010). Defer a persisted Service
Plan until real use shows the derived suggestion is not enough; the domain
model already warns against plan status complexity. That task must also settle
ADR 0007's open point that correcting a visit does not update its linked
completions.
Consequence: REQ-DOMAIN-009 stays vacuous until a plan exists; Service keeps
recording one operation at a time.

**D. Import data from the legacy spike app?**
Recommended: no importer. The owner re-enters the few baselines that matter
with "Mark done", which is also the path every new user takes.
Consequence: the title adapter and seed migration are never built (Q9, Q10);
the maintenance-engine success criterion about adapting seeded Arteon data
becomes obsolete (proposed change below). If yes, a one-way importer that
creates only confirmed completions and readings (never plans or statuses) is a
separate task.

## Proposed requirement change (owner approval pending)

`docs/requirements/maintenance-engine.md`, "Success criteria for engine v1":
the bullet "Current seeded Arteon data can be adapted without immediate
destructive migration" describes the legacy spike. If owner question D is
answered "no importer", replace it with: "No seeded future visit is a source of
maintenance truth; legacy spike data is not read." The text is unchanged until
the owner approves.

## Rejected alternatives

- **Closing the questions only in ADR 0001.** Twelve evidence entries and four
  owner questions would bury the original decision record; ADR 0001 gets a short
  closure section that points here.
- **Seeding a sample recommendation to exercise provenance.** Invented truth
  (core C2); the data question belongs to the owner.
- **Treating ADR 0001 as accepted because its decisions are implemented.**
  Acceptance of an owner-held ADR is an owner action.
