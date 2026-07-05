# Atomic Development Roadmap

## Phase 0 --- Documentation and domain freeze

### P0-001 Verify current domain audit

Goal: verify documented repository findings against the full workspace.

Tests first: - none; inspection task.

Acceptance: - every referenced current model/engine behavior has
file/type evidence; - discrepancies are written into
`11_CURRENT_DOMAIN_AUDIT.md`; - no code changes.

Failure: - task begins refactoring.

### P0-002 Accept ADR-001

Acceptance: - ten ADR questions have explicit decisions; - rejected
alternatives recorded; - no unresolved question required by the rule
spike.

### P0-003 Add telemetry policy docs

Acceptance: - event taxonomy approved; - logging categories approved; -
private-data denylist documented.

## Phase 1 --- Observability baseline

### OBS-001 Introduce app logging facade

Tests first: - test category mapping/configuration if facade contains
behavior.

Acceptance: - production `print` usage inventoried; - new code uses
`Logger`; - categories from observability spec exist; - privacy-safe
helpers documented.

### OBS-002 Add maintenance pipeline logging

Acceptance: - snapshot/planner future pipeline has a logging contract; -
correlation IDs available for multi-stage input flow; - no raw
note/transcript fields.

### OBS-003 Integrate Firebase Analytics

Acceptance: - Analytics SDK configured; - debug event visible in
DebugView; - analytics wrapper/protocol exists; - domain code does not
import Firebase; - analytics can be replaced by a no-op in tests.

Failure: - views call Firebase Analytics directly.

### OBS-004 Integrate Crashlytics

Acceptance: - test crash verified on non-production test build; -
dSYM/symbolication verified; - safe custom keys configured; - privacy
denylist reviewed.

## Phase 2 --- Maintenance operation identity

### MNT-001 Define stable MaintenanceOperationID

RED: - tests prove known fixture IDs are stable and localized titles do
not define identity.

GREEN: - pure Swift ID type.

Acceptance: - engineOilService, dsgService, awdCouplingService,
brakeFluid fixtures represented; - no SwiftData migration.

### MNT-002 Map current seeded tasks to operation IDs

RED: - parameterized mapping tests for current known task catalog.

Acceptance: - unknown title mapping is explicit and logged; - mapping is
an adapter, not new source of truth.

Failure: - fuzzy LLM mapping in domain path.

## Phase 3 --- Rule engine

### MNT-010 Distance policy

RED cases: - known baseline; - approaching; - due; - early completion.

Acceptance: - deterministic pure Swift result; - parameterized tests.

### MNT-011 Unknown baseline

RED: - policy known + no completion → `.unknown`.

Acceptance: - never subtract from zero.

### MNT-012 Time policy

RED: - before approach window; - approaching; - due.

### MNT-013 Distance-or-time policy

RED: - distance wins; - time wins; - both unknown dimensions.

Acceptance: - first configured threshold wins.

### MNT-014 Engine-hours-or-time experimental policy

RED: - known hours baseline; - missing baseline; - time fallback.

Feature status: - experimental, not default UI.

### MNT-015 Policy provenance

RED: - official recommendation and custom effective policy coexist.

Acceptance: - custom policy does not destroy source recommendation.

## Phase 4 --- Completion adapters

### MNT-020 Derive oil completions from current data

RED: - existing completed Arteon oil visits produce operation
completions.

Acceptance: - adapter only; - current storage unchanged.

### MNT-021 Derive task completions from current visits

RED: - done task maps to stable operation ID; - not-done task creates no
completion.

### MNT-022 Resolve duplicate oil facts

Goal: - document precedence among `includesOilChange`, oil task and
existing engine logic.

Acceptance: - conflict strategy tested; - no destructive migration.

## Phase 5 --- MaintenanceSnapshot

### MNT-030 Build operation progress projection

RED: - all fixture operations produce expected status.

### MNT-031 Aggregate overall status

RED: - any due → due; - else any approaching → approaching; - else known
up-to-date; - unknown handling follows ADR.

### MNT-032 Snapshot rebuild reason

Acceptance: - rebuild reasons enum exists; - structured log emitted; -
duration signpost exists if measurement shows value.

## Phase 6 --- Procedure composition

### PROC-001 Define MaintenanceProcedure domain model

RED: - required components are distinct from optional recommendations.

Acceptance: - provenance/applicability represented conceptually; - no
global DSG composition assumption.

### PROC-002 Engine-oil procedure fixture

Use only sourced/current-app fixture semantics.

RED: - procedure draft can preselect required components; - user
correction can remove an assumed component before confirmation.

## Phase 7 --- Service Planner

### PLAN-001 Compose due operations

RED: - all due operations included.

### PLAN-002 Compose due-nearby operations

RED: - inside grouping window included; - outside excluded; - original
anchor unchanged.

### PLAN-003 Add optional recommendations

RED: - optional item appears under Consider; - omission does not create
deferred/due status.

### PLAN-004 Add relevant service notes

RED: - active service-context notes are surfaced separately; - archived
notes excluded.

### PLAN-005 Partial service reconciliation

RED: - only performed operations reset.

This is a release-blocking invariant.

## Phase 8 --- One-glance UI

### UI-001 Status hero

Acceptance: - green/amber/orange semantics; - no `Vehicle OK`; - one
status + one supporting fact; - VoiceOver labels reviewed.

### UI-002 All maintenance statuses

Acceptance: - operation list explains unknown; - policy/source details
reachable; - no AI required.

### UI-003 Service scope screen

Sections: - Service; - Due nearby; - Consider; - Remember.

Acceptance: - user can understand why an item is present.

## Phase 9 --- Notes v1

### NOTE-001 CarNote persistence

Tests first: - active/archive lifecycle.

### NOTE-002 Notes screen

Acceptance: - All active notes visible; - archive reversible only if
product chooses explicit archive browser; otherwise document behavior.

### NOTE-003 Canonical contexts

RED: - one note may belong to multiple contexts.

### NOTE-004 Car Wash one-action requirement

Acceptance: - from app launch, active car-wash notes reachable by one
obvious action.

### NOTE-005 Share context notes

Acceptance: - plain-text Share Sheet; - no custom sharing backend.

## Phase 10 --- Tell PitStop text laboratory

### AI-001 Foundation Models availability abstraction

RED: - available/unavailable states map to app behavior.

### AI-002 Typed NoteDraft interpreter

RED: - golden evaluation set established before feature release.

### AI-003 Draft confirmation UI

Acceptance: - save/edit/cancel; - model output never writes directly.

### AI-004 Add odometer intent

Numeric extraction quality gate required.

### AI-005 Add car-wash history intent

Acceptance: - amount optional; - default currency visibly confirmable.

## Phase 11 --- Odometer readings

### ODO-001 Add reading domain model

No migration until strategy accepted.

### ODO-002 Latest valid reading projection

### ODO-003 Anomaly validation

Cases: - lower current reading; - huge jump; - historical older
reading; - same value later date.

### ODO-004 Freshness v1

Acceptance: - deterministic; - non-annoying prompt telemetry exists.

## Phase 12 --- History

### HIST-001 History event model

### HIST-002 Money value type

No `Double`.

### HIST-003 Timeline projection

### HIST-004 Service event actual operations

Release-blocking: - plan and actual work remain separate.

## Phase 13 --- Voice

Voice transcript feeds the same InputInterpreter.

No separate voice domain logic.

## Phase 14 --- Widget

Deterministic snapshot only.

No LLM dependency for widget rendering.

## Phase 15 --- TestFlight five-car beta

Release gate defined in `15_RELEASE_AND_BETA.md`.

## Phase 16+ --- gated investigations

-   Siri/App Intents;
-   document OCR/import;
-   CloudKit sync;
-   exact vehicle image catalog;
-   driving signals/CarPlay;
-   maintenance knowledge packs;
-   multi-car Garage;
-   shared family vehicle.

Promotion requires an accepted investigation result and task
decomposition.

## Parallel track --- Product design

-   `DSGN-001` current UI visual inventory.
-   `DSGN-002` minimal semantic color tokens.
-   `DSGN-003` three status-hero visual spikes.
-   `DSGN-004` friendly home hierarchy.

This track may run beside pure domain work but must not trigger a
generic theme engine.

## Parallel track --- Development diary and professional narrative

-   `DIARY-001` add diary template and directory.
-   `DIARY-002` create LinkedIn backlog.
-   `DIARY-003` create LinkedIn metrics CSV.
-   `DIARY-004` publish one evidence-based development post per week
    when a qualified diary story exists.
-   `DIARY-005` review metrics every four posts.

The diary is part of engineering documentation. LinkedIn publication is
a curated output, not source of truth.

## Naming gate

Keep `PitStop` as working name through initial beta.

Run a formal naming sprint only after day-30 interviews show whether
retained value is primarily maintenance planning or broader car memory.

## Notes refactor prerequisite

`NOTE-AUDIT-001 — Inventory existing seeded note-like cases`

Must complete before introducing the final Note persistence model.

Scope includes film/wrap, floor mats and every other code-seeded owner
thought/reminder already present in the app.

Output: - audit table in `11_CURRENT_DOMAIN_AUDIT.md`; -
classification; - characterization fixtures/tests; - explicit
migration/adaptation decision.

No existing seeded case may be removed as "demo data" without an
explicit decision.
