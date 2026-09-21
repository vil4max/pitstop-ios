# Domain Inventory

**Status:** authoritative inventory for greenfield implementation  
**Task:** DOM-001  
**Sources:** `../requirements/domain-model.md`, `../requirements/capture-pipeline.md`, `../requirements/road-domain-and-ui.md`, `../requirements/car-board-screen.md`

## Implementation snapshot (`main`)

| Area | In code today | Notes |
|---|---|---|
| Vehicle / provisional car | `ProvisionalCarContext`, `Vehicle`, `OdometerReading` | Domain models and reading facts on `main` |
| Car Board UI | `CarBoardView`, `CarBoardViewModel`, `CarEditorView`, `AppEnvironment` | Persisted car context with optional name and mileage edit (CB-001); design language, tile grid, detail scaffold, and utility layer in place (CB-002, ADR 0009); tiles show sparse states until CB-003…007 |
| Capture pipeline | `CaptureInput`, `MemoryProposal`, `RawProposalFactory`, `ProposalValidator`, `ConfirmationPolicy`, `DomainCommandMapper`, `DomainCommand` | Pure domain path with tests (DOM-003, ADR 0006); async orchestration, persistence, and UI in M4 |
| Road projection | `RoadProjector`, `RoadProjection`, `RoadMilestone`, `RoadSlot`, `PlannedVehicleEvent` | Pure projection with tests (CB-006, ADR 0008); Road tile and Road screen render it (CB-007) |
| Maintenance engine | `MaintenanceOperationID`, `MaintenancePolicy`, `MaintenanceCompletion`, `MaintenanceStatus` | Pure domain value models on `main`; engine logic pending |
| Persistence | `CarMemoryStore`, `SwiftDataCarMemoryStore`, `PitstopSchemaV1` | Command-only store behind a domain protocol (ENG-004, ADR 0007); not yet wired into the app (CB-001) |
| Notes | `Note`, `NotesSummary`, `UpdateNoteCommand`, `RememberPipeline` (raw), `NotesViewModel`, `NotesView` | Save, find, correct, archive, and restore without AI; Notes tile summarizes real notes (CB-003) |
| History | `HistoryEvent`, `HistoryTimeline`, `CorrectVehicleEventCommand`, `HistoryViewModel`, `HistoryView` | Record and correct events by hand; timeline projects events and confirmed completions; tile shows the latest (CB-004) |
| Service | `MaintenanceEngine`, `MaintenanceContext`, `MaintenanceOperationState`, `ServicePlanner`, `RevokeMaintenanceCompletionCommand`, `ServiceViewModel`, `ServiceView` | Deterministic status from the owner's intervals and confirmed completions, suggested visit scope, track / mark done / change interval / undo (CB-005, ADR 0010) |

`ProvisionalCarContext.firstLaunch` has `odometerKm: nil`, and the placeholder
board shows "Mileage unknown" until a reading is supplied (REQ-DOMAIN-002,
REQ-BOARD-004, REQ-BOARD-005). No reading history or maintenance baseline is
implemented yet.

## Core domain (`domain-model`)

| Concept | Role | Source of truth | Derived / calculated | Code (`main`) |
|---|---|---|---|---|
| Vehicle | Car identity and configuration | Vehicle facts + config | — | Partial (`ProvisionalCarContext`) |
| Odometer Reading | Mileage fact at a time | Reading history | Latest valid reading | — |
| Maintenance Operation | Stable maintenance identity | Operation ID | — | — |
| Maintenance Procedure | Composed service procedure | Procedure definition + provenance | — | — |
| Maintenance Recommendation | Sourced default interval/rule | Verified recommendation | — | — |
| Maintenance Policy | Effective rule per operation | Confirmed policy | — | — |
| Maintenance Anchor | Recurring service horizon | Policy + completions | — | — |
| Maintenance Completion | Confirmed performed work | Completion record | Cycle reset | — |
| Maintenance Progress | Progress toward next service | — | From completion + policy | — |
| Maintenance Status | `unknown` / `upToDate` / `approaching` / `due` | — | Maintenance engine | — |
| Service Planner | Composes visit proposal | — | Operation statuses, windows | — |
| Suggested Service Scope | Derived visit proposal | — | Planner output | — |
| Service Plan | Owner-accepted future visit | Plan entity | Presentation | — |
| Service Visit | Actual service history event | Visit record | Spend summaries | — |
| Note | Raw owner thought | `rawText`, `createdAt`, `status` | Semantic metadata | — |
| Note Context | Canonical navigation context | — | AI assignment (beta) | — |
| History Event | Real life event | Event record | Road eligibility input | — |

## Capture pipeline (`capture-pipeline`)

| Concept | Layer | Mutates state | Code (`main`) |
|---|---|---|---|
| CaptureInput | Input contract | No | `CaptureInput` |
| SemanticInterpreter | Optional interpreted-mode adapter | No | `SemanticInterpreting`, `RuleBasedInterpreter`, `NoSemanticInterpreter` (CAP-002, ADR 0011) |
| MemoryProposal | Raw-preservation or interpreted draft | No | `MemoryProposal` |
| ProposalValidator | Deterministic validation | No | `ProposalValidator` |
| ConfirmationPolicy | Risk-based outcome | No | `ConfirmationPolicy` + `MutationPermit` |
| DomainCommandMapper | Proposal → command | No | `DomainCommandMapper` |
| CreateNote | Domain command | Yes | `CreateNoteCommand` |
| RecordOdometerReading | Domain command | Yes | `RecordOdometerReadingCommand` |
| RecordVehicleFact | Domain command | Yes | `RecordVehicleFactCommand` |
| ConfirmMaintenanceCompletion | Domain command | Yes | `ConfirmMaintenanceCompletionCommand` |
| SetMaintenancePolicy | Domain command | Yes | `SetMaintenancePolicyCommand` |
| RecordVehicleEvent | Domain command | Yes | `RecordVehicleEventCommand` |
| RecordExpense | Domain command | Yes | `RecordExpenseCommand` |
| Raw preservation | Model-free mode and fallback | Via CreateNote after validation/policy | `RawProposalFactory` |
| RememberInPitStopIntent | System entry | No (→ CaptureInput) | — |

### MemoryProposal kinds (V1 product-core subset)

| Kind | V1 priority | Maps to command |
|---|---|---|
| rawNote | P0 | CreateNote |
| contextualNote | P0 | CreateNote |
| odometerReading | P0 | RecordOdometerReading |
| vehicleFact | P0 | RecordVehicleFact |
| maintenanceCompletion | P1 | ConfirmMaintenanceCompletion |
| maintenancePolicyDraft | P2 | SetMaintenancePolicy |
| vehicleEvent | P1 | RecordVehicleEvent |
| expense | P2 | RecordExpense |
| reminderCandidate | Deferred | — |
| unknown | Fallback | preserveRaw |

## Road domain (`road-domain-and-ui`)

| Concept | Type | Pure domain | Code (`main`) |
|---|---|---|---|
| RoadContext | Input snapshot | Yes | `RoadContext` |
| RoadProjection | Projection output | Yes | `RoadProjection`, `RoadProjector` |
| RoadMilestone | Eligible future/past marker | Yes | `RoadMilestone`, `RoadSlot` |
| Milestone eligibility rules | Deterministic filter | Yes | `RoadProjector` |
| Mixed time/mileage lanes | Projection rule | Yes | ADR 0008: one lane, ordering key in horizon units |
| Horizon selection | Projection rule | Investigate INV-ROAD-001 | `RoadHorizon` (ADR 0008) |
| Clustering | Projection rule | Investigate INV-ROAD-003 | per-dimension clustering (ADR 0008) |
| Return to current | UI behaviour | Investigate INV-ROAD-004 | — |

### Milestone eligibility (deterministic)

| Candidate | Road milestone by default |
|---|---|
| Maintenance anchor approaching/due | Yes |
| Required service | Yes |
| Insurance expiry (known) | Yes |
| Explicit planned vehicle event | Yes |
| Car wash | No |
| Ordinary note | No |
| Generic reminder | No |
| Every history event | No |
| Low-confidence AI suggestion | No |

## Car Board projections (`car-board-screen`)

| Surface | Domain inputs | Code (`main`) |
|---|---|---|
| Car Hero | Vehicle + provisional state | Placeholder UI |
| Road tile | `RoadProjection` | Placeholder UI |
| Notes tile | Note summaries | Placeholder UI |
| Service tile | Maintenance status summary | Placeholder UI |
| History tile | History event summaries | Placeholder UI |
| Settings utility | App settings | — |
| Pit utility | Capture surface entry | — |

## Forbidden conflations (must hold in implementation)

| Do not conflate | Enforced by |
|---|---|
| Recommendation ↔ effective policy | Domain types + commands |
| Planned work ↔ performed work | Service plan vs completion |
| Visit ↔ operation completion | Service visit model |
| AI proposal ↔ persisted truth | Capture pipeline boundary |
| Note context ↔ raw note | Note model |
| Expense ↔ standalone accounting | History event attribute |

## Gap summary → next tasks

| Gap | Task |
|---|---|
| No inventory fixtures | DOM-002 |
| Capture types and policy tests | DOM-003 (done on branch) |
| Persistence schema intentionally deferred to ENG-004 | ENG-004 |
| Road rules undecided | INV-ROAD-001…004 |
| No real Car Board data | CB-001…007 |
| No capture UI/pipeline | CAP-001…007 |

## Legacy reference

Tab-bar app on `legacy/spike` contains prior maintenance engine, SwiftData models, and seed import. **Not** source of truth for greenfield domain shapes — use this inventory and specs only.

For historical seeded-domain findings from the spike era, see `../planning/legacy-domain-audit.md`. Treat that audit as legacy reference, not as the current `main` inventory.

## Related documents

- `../PROJECT_STATUS.md` — freeze / resume status and product-baseline definition
- `../planning/ai-roadmap.md` — deferred AI roadmap
- `../decisions/0004-product-design-rationale.md` — product why
- `../requirements/capture-pipeline.md` — Capture / Remember contract
- `../requirements/domain-model.md` — domain concept owner
