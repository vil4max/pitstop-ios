# Domain Inventory

**Status:** authoritative inventory for greenfield implementation  
**Task:** DOM-001  
**Sources:** `../requirements/domain-model.md`, `../requirements/capture-pipeline.md`, `../requirements/road-domain-and-ui.md`, `../requirements/car-board-screen.md`

## Implementation snapshot (`main`)

| Area | In code today | Notes |
|---|---|---|
| Vehicle / provisional car | `ProvisionalCarContext`, `Vehicle`, `OdometerReading` | Domain models and reading facts on `main` |
| Car Board UI | `CarBoardView`, `CarBoardViewModel`, `CarEditorView`, `AppEnvironment` | Persisted car context with optional name and mileage edit (CB-001); design language, tile grid, detail scaffold, and utility layer in place (CB-002, ADR 0009); four live tiles (CB-003…007) |
| Capture pipeline | `CaptureInput`, `MemoryProposal`, `RawProposalFactory`, `ProposalValidator`, `ConfirmationPolicy`, `DomainCommandMapper`, `DomainCommand` | Domain path (DOM-003, ADR 0006) plus `RememberPipeline` orchestration, deadline and cancellation (ADR 0015), persisted through the store and driven by Pit and Siri (CAP-001…007) |
| Road projection | `RoadProjector`, `RoadProjection`, `RoadMilestone`, `RoadSlot`, `PlannedVehicleEvent`, `MileageObservation`, `MileageRateEstimator`, `MileageRate`, `EstimatedDateRange` | Pure projection with tests (CB-006, ADR 0008); Road tile and Road screen render it (CB-007); a distance milestone carries a derived, never stored date estimate from the reading history (ROAD-EST-002, ADR 0034) |
| Planned dates | `PlannedDatedEvent`, `PlannedEventLimits`, `AddPlannedEventCommand`, `UpdatePlannedEventCommand`, `RemovePlannedEventCommand`, `PlannedEventEditorView` | Owner-stated insurance expiry or other date with an optional label; entered, corrected and deleted on Road; one insurance expiry on Road per car; fed into Road and the Road tile (ROAD-EVT-001, ADR 0032) |
| Maintenance engine | `MaintenanceOperationID`, `MaintenancePolicy`, `MaintenanceCompletion`, `MaintenanceStatus`, `VehicleServiceReport` | `MaintenanceEngine` derives status from policies, confirmed completions and the car's own dashboard reading; reading anchors are derived on read, the earlier anchor wins per dimension, and a newer completion supersedes the reading (ADR 0010, 0020, 0035) |
| Persistence | `CarMemoryStore`, `SwiftDataCarMemoryStore`, `PitstopSchemaV1`, `PitstopSchemaV2`, `PitstopSchemaV3`, `PitstopSchemaV4` | Command-only store behind a domain protocol (ENG-004, ADR 0007); V2 adds persisted Pit question state with a lightweight migration from V1 (ADR 0016); V3 adds planned dates with a second lightweight stage, and V2 is frozen (ADR 0032); V4 adds dashboard readings (the newest per operation counts; older rows stay mileage observations and reject replays) with a third lightweight stage, and V3 is frozen (ADR 0035) |
| Notes | `Note`, `NotesSummary`, `UpdateNoteCommand`, `RememberPipeline` (raw), `NotesViewModel`, `NotesView` | Save, find, correct, archive, and restore without AI; Notes tile summarizes real notes (CB-003) |
| History | `HistoryEvent`, `HistoryTimeline`, `CorrectVehicleEventCommand`, `HistoryViewModel`, `HistoryView` | Record and correct events by hand; timeline projects events and confirmed completions; tile shows the latest (CB-004) |
| Service | `MaintenanceEngine`, `MaintenanceContext`, `MaintenanceOperationState`, `ServicePlanner`, `RevokeMaintenanceCompletionCommand`, `StopTrackingOperationCommand`, `RecordVehicleServiceReportCommand`, `RemoveVehicleServiceReportCommand`, `ServiceViewModel`, `ServiceView`, `DashboardReadingView`, `OwnerInterval`, `TrackSeveralViewModel`, `TrackSeveralView` | Deterministic status from the owner's intervals and confirmed completions, suggested visit scope, track / track several / mark done / change interval / undo / stop tracking / enter and delete a dashboard reading; "Track several" writes one `setMaintenancePolicy` (`userCustom`) per confirmed item and stores no car-type answer (CB-005, MNT-POL-001, MNT-PRE-001, MNT-VR-002, ADR 0010, 0031, 0033, 0035) |
| Pit | `PitPresenceModel`, `PitCaptureViewModel`, `PitQuestionRegistry`, `PitQuestionViewModel`, `PitActivitySources` | Capture surface, proposal confirmation, current-mileage question with cooldown and return, activity reporting (CAP-003/004, DISC-001…004, ADR 0012, 0016–0019) |
| Interpretation | `RuleBasedInterpreter`, `InterpreterChain`, `FoundationModelsInterpreter` | Rules by default; the Foundation Models adapter runs only behind a DEBUG launch argument (CAP-005, ADR 0011, 0027) |
| System capture | `RememberInPitStopIntent`, `RememberIntentHandler`, `PitStopShortcuts`, `OpenPitIntent`, `CaptureSurfaceRequests`, `PitstopWidgets` | Siri and App Shortcuts, voice clarification, Open Pit control and data-free widget (SYS-002…006, ADR 0023–0026) |
| Analytics | `AnalyticsClient`, `PostHogAnalyticsClient` | Provider-neutral boundary, consent off by default, HTTP adapter without an SDK (ENG-002, ANL-001, ADR 0021, 0022) |

`ProvisionalCarContext.firstLaunch` has `odometerKm: nil`, and the placeholder
board shows "Mileage unknown" until a reading is supplied (REQ-DOMAIN-002,
REQ-BOARD-004, REQ-BOARD-005). Readings and confirmed completions are stored
facts; the header shows the newest mileage observation (REQ-BOARD-026).

## Core domain (`domain-model`)

| Concept | Role | Source of truth | Derived / calculated | Code (`main`) |
|---|---|---|---|---|
| Vehicle | Car identity and configuration | Vehicle facts + config | — | `Vehicle`, `ProvisionalCarContext` |
| Odometer Reading | Mileage fact at a time | Reading history | Latest valid reading; mileage rate, derived on read and never stored (ADR 0034) | `OdometerReading`, `MileageRateEstimator` |
| Maintenance Operation | Stable maintenance identity | Operation ID | — | `MaintenanceOperationID` |
| Maintenance Procedure | Composed service procedure | Procedure definition + provenance | — | — |
| Maintenance Recommendation | Sourced default interval/rule | Verified recommendation | — | — |
| Maintenance Policy | Effective rule per operation | Confirmed policy | — | `MaintenancePolicy` |
| Maintenance Anchor | Recurring service horizon | Policy + completions, or a dashboard reading | Earlier anchor per dimension (ADR 0035) | — |
| Maintenance Completion | Confirmed performed work | Completion record | Cycle reset | `MaintenanceCompletion` |
| Vehicle Service Report | What the car's display said was left for one operation | Reading records; the newest per operation counts (ADR 0035) | Report anchors, derived on read; never a policy, never a cycle reset | `VehicleServiceReport` |
| Maintenance Progress | Progress toward next service | — | From completion + policy and the newest valid dashboard reading | `MaintenanceOperationState` |
| Maintenance Status | `unknown` / `upToDate` / `approaching` / `due` | — | Maintenance engine | `MaintenanceStatus`, `MaintenanceEngine` |
| Service Planner | Composes visit proposal | — | Operation statuses, windows | `ServicePlanner` |
| Suggested Service Scope | Derived visit proposal | — | Planner output | `SuggestedServiceScope` |
| Service Plan | Owner-accepted future visit | Plan entity | Presentation | — |
| Service Visit | Actual service history event | Visit record | Spend summaries | — |
| Note | Raw owner thought | `rawText`, `createdAt`, `status` | Semantic metadata | `Note` |
| Note Context | Canonical navigation context | — | AI assignment (beta) | `NoteContext` |
| History Event | Real life event | Event record | Road eligibility input | `HistoryEvent` |

## Capture pipeline (`capture-pipeline`)

| Concept | Layer | Mutates state | Code (`main`) |
|---|---|---|---|
| CaptureInput | Input contract | No | `CaptureInput` |
| SemanticInterpreter | Optional interpreted-mode adapter | No | `SemanticInterpreting`, `RuleBasedInterpreter`, `NoSemanticInterpreter` (CAP-002, ADR 0011); `InterpreterChain`, `FoundationModelsInterpreter` (CAP-005, ADR 0027) |
| MemoryProposal | Raw-preservation or interpreted draft | No | `MemoryProposal` |
| ProposalValidator | Deterministic validation | No | `ProposalValidator` |
| ConfirmationPolicy | Risk-based outcome | No | `ConfirmationPolicy` + `MutationPermit` |
| DomainCommandMapper | Proposal → command | No | `DomainCommandMapper` |
| CreateNote | Domain command | Yes | `CreateNoteCommand` |
| RecordOdometerReading | Domain command | Yes | `RecordOdometerReadingCommand` |
| RecordVehicleFact | Domain command | Yes | `RecordVehicleFactCommand` |
| ConfirmMaintenanceCompletion | Domain command | Yes | `ConfirmMaintenanceCompletionCommand` |
| SetMaintenancePolicy | Domain command | Yes | `SetMaintenancePolicyCommand` |
| StopTrackingOperation | Domain command, user-only (no proposal maps to it) | Yes | `StopTrackingOperationCommand` (ADR 0031) |
| RecordVehicleEvent | Domain command | Yes | `RecordVehicleEventCommand` |
| RecordExpense | Domain command | Yes | `RecordExpenseCommand` |
| AddPlannedEvent / UpdatePlannedEvent / RemovePlannedEvent | Domain commands, user-only (no proposal maps to them) | Yes | `AddPlannedEventCommand`, `UpdatePlannedEventCommand`, `RemovePlannedEventCommand` (ADR 0032) |
| Raw preservation | Model-free mode and fallback | Via CreateNote after validation/policy | `RawProposalFactory` |
| RememberInPitStopIntent | System entry | No (→ CaptureInput) | `RememberInPitStopIntent` (ADR 0023) |

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
| Planned dated event | Owner-stated future date, stored | Yes | `PlannedDatedEvent` → `PlannedVehicleEvent` (ADR 0032) |
| Milestone eligibility rules | Deterministic filter | Yes | `RoadProjector` |
| Mixed time/mileage lanes | Projection rule | Yes | ADR 0008: one lane, ordering key in horizon units |
| Horizon selection | Projection rule | Yes | `RoadHorizon` (ADR 0008) |
| Clustering | Projection rule | Yes | per-dimension clustering (ADR 0008) |
| Return to current | UI behaviour | No (UI) | "Back to now" in `RoadView` (ADR 0008) |

### Milestone eligibility (deterministic)

| Candidate | Road milestone by default |
|---|---|
| Maintenance anchor approaching/due | Yes |
| Required service | Yes |
| Insurance expiry (known) | Yes (stated on Road, ADR 0032) |
| Explicit planned vehicle event | Yes |
| Car wash | No |
| Ordinary note | No |
| Generic reminder | No |
| Every history event | No |
| Low-confidence AI suggestion | No |

## Car Board projections (`car-board-screen`)

| Surface | Domain inputs | Code (`main`) |
|---|---|---|
| Car Hero | Vehicle + provisional state | `CarHeroView` |
| Road tile | `RoadProjection` | `CarBoardTileView`, `RoadView` |
| Notes tile | Note summaries | `CarBoardTileView`, `NotesView` |
| Service tile | Maintenance status summary | `CarBoardTileView`, `ServiceView` |
| History tile | History event summaries | `CarBoardTileView`, `HistoryView` |
| Settings utility | App settings | `SettingsView` |
| Pit utility | Capture surface entry | `PitCaptureView`, `PitPresenceModel` |

## Forbidden conflations (must hold in implementation)

| Do not conflate | Enforced by |
|---|---|
| Recommendation ↔ effective policy | Domain types + commands |
| Planned work ↔ performed work | Service plan vs completion |
| Visit ↔ operation completion | Service visit model |
| AI proposal ↔ persisted truth | Capture pipeline boundary |
| Note context ↔ raw note | Note model |
| Expense ↔ standalone accounting | History event attribute |

## Open work

Remaining tasks and owner decisions live in
[`../planning/work-plan.md`](../planning/work-plan.md). The pre-greenfield
tab-bar spike is not part of this repository (ADR 0014); ADR 0020 records how
its maintenance ideas were closed.

## Related documents

- `../PROJECT_STATUS.md` — freeze / resume status and product-baseline definition
- `../planning/ai-roadmap.md` — deferred AI roadmap
- `../decisions/0004-product-design-rationale.md` — product why
- `../requirements/capture-pipeline.md` — Capture / Remember contract
- `../requirements/domain-model.md` — domain concept owner
