# Work Plan

**Status:** authoritative execution horizon  
**WIP limit:** 1 (solo)  
**Estimates:** ideal focused dev days  
**GitHub:** one issue per active task only — see [`24_PROJECT_MANAGEMENT_AND_GITFLOW.md`](24_PROJECT_MANAGEMENT_AND_GITFLOW.md)

## Milestones

| Milestone | Exit criteria | Cumulative est. |
|---|---|---:|
| M0 | This plan approved; spec lifecycle documented | — |
| M1 | `legacy/spike` exists; BOOT-001 builds; ENG-001 + ENG-003 | ~8d |
| M2 | DOM-003 tests pass; INV-ROAD decisions documented | ~11d |
| M3 | Car Board tiles + Road; provisional car; no tab bar | ~21d |
| M4 | Remember end-to-end capture slice | ~21d |

Calendar solo multiplier: ×1.4–1.6 → M4 ≈ 12–16 weeks.

## Status legend

| Status | Meaning |
|---|---|
| `contract` | Accepted spec; no implementation issue |
| `done` | Completed; no issue |
| `ready` | Next candidate; no GitHub issue yet |
| `tracked` | GitHub issue open |
| `deferred` | Out of current scope |

## Phase 0 — Product contracts

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| P0-001 | Product charter accepted | — | — | contract | — |
| P0-002 | Car Board contract accepted | — | — | contract | — |
| P0-003 | Road investigations defined | — | — | contract | — |
| P0-004 | Pit behaviour boundary accepted | — | — | contract | — |
| P0-005 | Capture pipeline boundary accepted | — | — | contract | — |
| MIG-001 | Product direction migration note | — | — | done | — |

## Phase 1 — Domain

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DOM-001 | Domain inventory from specs (`02`, `34`, `32`) | 1d | — | ready | — |
| DOM-002 | Spec-derived test fixtures | 1d | DOM-001 | ready | — |
| DOM-003 | Capture domain types + confirmation policy tests | 4d | DOM-001 | ready | — |
| DOM-004 | ADR-001 open questions closure | 1d | — | ready | — |

## Phase 2 — Engineering bootstrap

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| BOOT-001 | Greenfield app target + folder tree + empty build | 2d | — | done | — |
| ENG-001 | Logging facade | 1d | BOOT-001 | done | — |
| ENG-003 | CI quality gates | 2d | BOOT-001 | done | — |
| ENG-004 | Persistence + provisional car context | 3d | DOM-003, BOOT-001 | ready | — |
| ENG-002 | Analytics boundary | 2d | CB-002 | deferred | — |
| ANL-001 | Provider-neutral analytics spike | 2d | ENG-002 | deferred | — |

## Road investigations

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| INV-ROAD-001 | Horizon and spacing | 1d | — | ready | — |
| INV-ROAD-002 | Mixed time/mileage representation | 1d | — | ready | — |
| INV-ROAD-003 | Milestone clustering | 1d | INV-ROAD-001 | ready | — |
| INV-ROAD-004 | Return to current position | 1d | INV-ROAD-001 | ready | — |

## Phase 3 — Car Board

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CB-001 | Provisional car context | 2d | ENG-004 | ready | — |
| CB-002 | Car Board shell + utility layer + screen grammar | 4d | CB-001, ENG-003 | ready | — |
| CB-003 | Notes tile + entry | 2d | CB-002, DOM-003 | ready | — |
| CB-004 | History tile + entry | 2d | CB-002 | ready | — |
| CB-005 | Service tile summary | 3d | CB-002 | ready | — |
| CB-006 | Road projection domain + tests | 4d | DOM-001, INV-ROAD-* | ready | — |
| CB-007 | Road UI | 4d | CB-006, INV-ROAD-* | ready | — |

## Phase 4 — Capture / Pit

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CAP-001 | CaptureInput boundary | 2d | DOM-003 | ready | — |
| CAP-002 | Proposal + confirmation without live model | 3d | CAP-001 | ready | — |
| CAP-003 | Pit Eyes affordance | 2d | CB-002 | ready | — |
| CAP-004 | Pit Capture Surface | 3d | CAP-001, CAP-003 | ready | — |
| CAP-005 | Foundation Models interpreter spike (RU) | 5d | CAP-002 | ready | — |
| CAP-006 | Raw-preservation fallback | 2d | CAP-002 | ready | — |
| CAP-007 | End-to-end Remember slice | 4d | CAP-004–006, ENG-004 | ready | — |

## Phase 5 — Progressive discovery

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DISC-001 | Question value registry | 2d | M4 | deferred | — |
| DISC-002 | First high-value question | 3d | DISC-001 | deferred | — |
| DISC-003 | Attention cooldown policy | 2d | DISC-001 | deferred | — |
| DISC-004 | Pit semantic motion | 3d | CAP-003 | deferred | — |

## Phase 6 — System capture

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| SYS-001 | App Intent investigation | 1d | CAP-007 | deferred | — |
| SYS-002 | RememberInPitStopIntent | 2d | SYS-001 | deferred | — |
| SYS-003 | App Shortcut | 1d | CAP-007 | deferred | — |
| SYS-004 | Widget investigation | 1d | CAP-007 | deferred | — |
| SYS-005 | Widget capture slice | 3d | SYS-004 | deferred | — |
| SYS-006 | Siri capture slice | 3d | SYS-002 | deferred | — |

## Phase 7 — Maintenance intelligence

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| MNT-INT-001 | Manufacturer data + preset strategy investigations | 5d+ | M4 | deferred | — |

## Legacy

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| LEG-001 | Tab-bar spike preserved on `legacy/spike` | — | — | done | — |

```text
BOOT-001 → ENG-001 → ENG-003 → DOM-001 → DOM-003 → ENG-004
→ INV-ROAD-* → CB-001 → CB-002 → CB-003/004/005 → CB-006 → CB-007
→ CAP-001…007
```

## Rolling export rule

1. Pick next `ready` row.
2. Create one GitHub issue (body from [`16_TASK_TEMPLATE.md`](16_TASK_TEMPLATE.md)).
3. Set row to `tracked` + issue number.
4. On merge: `done`; remove duplicate detail from [`08_ROADMAP.md`](08_ROADMAP.md).
