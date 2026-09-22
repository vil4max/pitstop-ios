# Persistence: SwiftData Behind a Command-Only Store

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-20); owner review pending\
**Task:** ENG-004\
**Contracts:** [`../requirements/domain-model.md`](../requirements/domain-model.md),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)

## Context

Nothing was persisted: the app rebuilt `ProvisionalCarContext.firstLaunch` on
every start. The engineering standard forbids redesigning persistence without
an ADR, and the modular architecture forbids SwiftData types in the domain or
in feature view state.

## Decision

### One store protocol, one write path

`CarMemoryStore` (in `Domain/Store`) exposes typed reads and a single write:
`execute(_ command: DomainCommand, now:)`. The store validates the command
before touching storage and rolls the context back when a save fails, so a
thrown error always means nothing was saved. This is what lets later UI report
success only after persistence succeeded (REQ-CAPTURE-009) and keeps Siri,
widgets, and a model adapter from writing records directly (REQ-CAPTURE-004).

### SwiftData as the adapter

`SwiftDataCarMemoryStore` is a `@ModelActor`. `@Model` classes are not
`Sendable`, so they never leave the actor; every read maps records to domain
values first. The Swift 6 compiler enforces that boundary.

### Schema rules

- `PitstopSchemaV1` is a `VersionedSchema` with a `SchemaMigrationPlan` from
  the first version, so the second version is a migration stage, not a retrofit.
- Enums are stored as raw strings, IDs as `UUID`. Unknown raw values map to a
  safe visible default (`.other`, `.active`), except a reading with an
  unreadable unit, which is dropped: guessing kilometres would invent mileage.
- No relationships in V1. Records carry `vehicleID`; with one car (core C1)
  relationships add migration cost and no query value.
- The vehicle record has no odometer column. The latest reading is
  `readings.latest`, a projection over history (REQ-DOMAIN-001); an empty
  history is `nil`, never zero (REQ-DOMAIN-002).
- Policy rows are keyed by vehicle, operation, and source. Setting a custom
  policy never touches the `defaultRecommendation` row; the effective rule is
  the projection `policies.effective` (custom over vehicle condition over
  recommendation), so REQ-DOMAIN-006 holds in storage. An earlier draft keyed
  rows by operation only and destroyed the recommendation; independent review
  caught it.
- Record IDs are unique attributes, which makes SwiftData upsert on insert.
  The store therefore rejects a reading, event, or completion whose ID already
  exists (`duplicateRecord`) instead of silently rewriting history.
- The provisional car uses the fixed `Vehicle.provisionalID`, so the app and a
  future extension that open the same file, one after the other, see one car
  instead of two. This is not a concurrency guarantee: if a second process
  inserted the provisional car after the first process had already saved a
  fact, the unique-ID upsert could reset that car. Only the app process opens
  the store today; SYS-002/SYS-005 must settle cross-process access (shared
  container, single writer) before an extension writes.
- A rejected command creates nothing, including the provisional car: only
  `currentVehicle()` creates it.
- `failNextSave()` is a DEBUG-only seam. SwiftData offers no way to provoke a
  save failure, and "a failed save leaves nothing behind" (REQ-CAPTURE-009) is
  too important to leave untested.

### Provisional car

`currentVehicle()` creates `Vehicle.provisional()` when no vehicle exists, so
first launch needs no setup step (core P2). `Vehicle.isProvisional` is a
persisted domain flag; applying any confirmed `VehicleFact` clears it. The
provisional car creates no reading, policy, completion, or event
(REQ-DOMAIN-003).

## History projection and correction (CB-004)

`HistoryTimeline` is a pure projection over recorded events and confirmed
completions, newest first with ties broken by ID. A completion whose
`sourceEventID` names an event in the same timeline is represented by that
event and not listed twice; if the named event is missing, the completion is
listed itself so it can never vanish. Notes, plans, and proposals are not inputs.

`CorrectVehicleEventCommand` replaces the facts of an existing event and keeps
its ID and vehicle. "Never rewrites history" above is about repeated or forged
writes; a correction is an explicit user action, and stored data must be
inspectable and correctable (core P1). Limits:

- A correction passes the same checks as a new event, so it cannot move an
  event into the future. It may clear mileage, cost, or note: the user can stop
  trusting a fact, and unknown is a valid state.
- An event with an amount is still one History event. `RecordExpense` differs
  only at capture time, where a proposal of kind `expense` must carry an amount;
  hand entry and correction use the event commands.
- Correcting a visit does not yet update completions linked to it through
  `sourceEventID`. Nothing creates such links before CB-005, which owns that
  rule.
- There is no delete. No contract requires it; a mistaken event is corrected.
- Amounts have no currency in the domain, so History shows a plain number.

## Rejected alternatives

- **Generic `Repository<T>`.** Hides domain semantics and invites ad-hoc
  writes; the architecture guide lists it as a failure mode.
- **`@Query` in views.** Leaks records into view state and bypasses commands.
- **Codable files or `UserDefaults`.** No migration story and no partial
  reads once notes and history grow.
- **Reusing the `legacy/spike` models.** They predate the current domain
  inventory, which names the spike as not a source of truth.
- **A confirmed completion also inserting a History event.** That conflates
  completion with visit. History is a projection instead (see below).

## Consequences and limits

- The store file was `Application Support/Pitstop.store` in the app's
  container. Since ADR 0036 it lives in the App Group container, moved there
  once at launch, and the next-service widget reads it read-only. There is no
  iCloud sync, export, or deletion flow yet.
- Correcting or archiving a note uses `UpdateNoteCommand` (CB-003). It changes
  text or status only and can never create an event or completion.
- App wiring (container creation at launch and the failure path when the
  container cannot open) belongs to CB-001.
