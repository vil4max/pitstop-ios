# Domain Inventory

**Status:** authoritative inventory for greenfield implementation  
**Task:** DOM-001  
**Sources:** `02_DOMAIN_MODEL.md`, `34_CAPTURE_PIPELINE_SPEC.md`, `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`, `31_CAR_BOARD_SCREEN_CONTRACT.md`

## Implementation snapshot (`main`)

| Area | In code today | Notes |
|---|---|---|
| Vehicle / provisional car | `ProvisionalCarContext` | Name, odometer, optional make/model/year only |
| Car Board UI | `CarBoardView` placeholder | Tiles and utility buttons not wired |
| Capture pipeline | — | Not started |
| Road projection | — | Not started |
| Maintenance engine | — | Legacy on `legacy/spike` only |
| Persistence | — | Not started |
| Notes / History / Service | — | Not started |

## Core domain (`02`)

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

## Capture pipeline (`34`)

| Concept | Layer | Mutates state | Code (`main`) |
|---|---|---|---|
| CaptureInput | Input contract | No | — |
| SemanticInterpreter | AI adapter | No | — |
| MemoryProposal | Draft interpretation | No | — |
| ProposalValidator | Deterministic validation | No | — |
| ConfirmationPolicy | Risk-based outcome | No | — |
| DomainCommandMapper | Proposal → command | No | — |
| CreateNote | Domain command | Yes | — |
| RecordOdometerReading | Domain command | Yes | — |
| RecordVehicleFact | Domain command | Yes | — |
| ConfirmMaintenanceCompletion | Domain command | Yes | — |
| SetMaintenancePolicy | Domain command | Yes | — |
| RecordVehicleEvent | Domain command | Yes | — |
| RecordExpense | Domain command | Yes | — |
| Raw preservation | Fallback path | Yes (as Note/raw) | — |
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

## Road domain (`32`)

| Concept | Type | Pure domain | Code (`main`) |
|---|---|---|---|
| RoadContext | Input snapshot | Yes | — |
| RoadProjection | Projection output | Yes | — |
| RoadMilestone | Eligible future/past marker | Yes | — |
| Milestone eligibility rules | Deterministic filter | Yes | — |
| Mixed time/mileage lanes | Projection rule | Yes | — |
| Horizon selection | Projection rule | Investigate INV-ROAD-001 | — |
| Clustering | Projection rule | Investigate INV-ROAD-003 | — |
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

## Car Board projections (`31`)

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
| No capture types/tests | DOM-003 |
| No persistence / provisional car store | ENG-004 |
| Road rules undecided | INV-ROAD-001…004 |
| No real Car Board data | CB-001…007 |
| No capture UI/pipeline | CAP-001…007 |

## Legacy reference

Tab-bar app on `legacy/spike` contains prior maintenance engine, SwiftData models, and seed import. **Not** source of truth for greenfield domain shapes — use this inventory and specs only.
