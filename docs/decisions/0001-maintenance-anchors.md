# ADR-001: Independent Maintenance Cycles and Service Composition

**Status:** Proposed\
**Decision owner:** PitStop\
**Date:** 2026-07

## Context

The current application uses seeded future service visits and visit
tasks. Oil also has dedicated calculations and flags.

The target product must support: - different official schedules by
vehicle; - user-selected per-operation intervals; - frequent oil
cadence; - rarer mandatory transmission/AWD cycles; - time-based
operations; - grouping nearby work into one practical visit; - partial
service completion.

## Decision

### 1. Recurring maintenance operations are independent from service visits

Accepted.

An operation/procedure owns its policy and lifecycle.

### 2. An interval is a service anchor/horizon, not a vehicle-health threshold

Accepted.

Copy must not claim a component becomes bad at the exact anchor.

### 3. Early completion resets from actual completion facts

Accepted by default.

Fixed-grid semantics require a future explicit policy type.

### 4. Multiple operations may be grouped into one suggested service scope

Accepted.

Grouping is deterministic derived planning.

### 5. Grouping is non-authoritative

Accepted.

Grouping does not move/reset the original cycle.

### 6. Official recommendation and user policy are separate

Accepted.

The effective policy drives status. Provenance is preserved.

### 7. Status is calculated only from effective policy and confirmed facts

Accepted.

AI output cannot set status.

### 8. Missing baseline is represented as unknown

Accepted.

No implicit zero baseline.

### 9. Stable operation IDs must replace localized-title identity

Accepted.

Current title mapping is a temporary adapter.

### 10. Pending seeded visits must stop being authoritative future schedule

Accepted direction.

Migration timing remains gated by adapters/tests.

## Additional decision: service procedure composition

A maintenance procedure may define sourced required components.

Required procedure components are distinct from: - independently due
operations; - due-nearby operations; - optional recommendations.

Actual completion is confirmed separately from the procedure draft.

## Additional decision: Service Plan

A `ServicePlan` represents the owner's accepted future scope.

A `ServiceVisit` represents actual history.

They are not the same source of truth.

## Consequences

Positive: - oil is no longer a permanent engine special case; -
DSG/AWD/brake-fluid cycles are first-class; - practical combined service visits are
natural; - partial service is correct; - official and custom schedules
can coexist.

Costs: - current seed-plan model needs adapters and eventual
migration; - operation identity catalog is required; - procedure
applicability/provenance becomes a data problem; - planner requires
explicit grouping rules.

## Closure (DOM-004, 2026-09-21)

The open points of this ADR are closed in
[`0020-maintenance-anchor-closure.md`](0020-maintenance-anchor-closure.md),
with evidence from code and tests. Summary:

| Open point | State |
|---|---|
| Decisions 1, 2, 4, 5, 7, 8 | Decided and implemented (ADR 0010, engine and planner tests) |
| Decision 3: early completion reset | Implemented; fixed-grid policy type not added in the first slice (ADR 0020, Q3) |
| Decision 6: official vs user policy | Separation implemented (ADR 0007, 0010); recommendation data is owner question B |
| Decision 9: stable IDs, title adapter | IDs implemented and pinned by tests; no title adapter (ADR 0020, Q9) |
| Decision 10: seeded visits, migration timing | No seeded visits on greenfield `main`; nothing to migrate unless owner question D says import |
| Costs: grouping rules, identity catalog | Windows in ADR 0010; eligibility and catalog decided in ADR 0020 (Q5, Q11) |
| Procedure composition | Owner question B (verified data source) |
| Service Plan vs Service Visit | Separation implemented; plan and multi-operation visit scope are owner question C |
| Status of this ADR | Owner question A: recommended `Accepted` |

## Rejected alternatives

### Keep future visits as the maintenance source of truth

Rejected because policy changes and early completion make rigid
pre-generated visits fragile.

### One global "conservative maintenance" mode

Rejected because owners may customize oil while following official
DSG/brake rules.

### Let LLM compose the service visit

Rejected as source-of-truth logic. LLM may phrase or explain a
deterministic plan.

### Mark all visit tasks complete when visit completes

Rejected because real services are partial.

## Review trigger

Review this ADR only if: - five-car beta shows users do not think in
independent maintenance cycles; - official schedule data cannot be
normalized into operation/procedure policies; - service grouping creates
systematic confusion.
