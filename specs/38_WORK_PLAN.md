# Work Plan

**Status:** authoritative execution horizon  
**Board:** [PitStop GitHub Project #2](https://github.com/users/vil4max/projects/2)  
**WIP limit:** 1 implementation task in **In progress** (solo)  
**Estimates:** ideal focused dev days  
**Process:** [`24_PROJECT_MANAGEMENT_AND_GITFLOW.md`](24_PROJECT_MANAGEMENT_AND_GITFLOW.md)

## Milestones

| Milestone | Exit criteria | Cumulative est. |
|---|---|---:|
| M0 | Work plan + board + CI | — |
| M1 | `legacy/spike`; BOOT-001; ENG-001; ENG-003 | ~8d |
| M2 | DOM-003 tests; INV-ROAD decisions | ~11d |
| M3 | Car Board tiles + Road | ~21d |
| M4 | Remember end-to-end | ~21d |

Calendar solo multiplier: ×1.4–1.6 → M4 ≈ 12–16 weeks.

## Status legend

| Status | Meaning |
|---|---|
| `contract` | Accepted spec; no issue |
| `done` | Shipped; issue closed |
| `tracked` | GitHub issue in backlog or active |
| `deferred` | Later phase; issue exists, low priority |

## Git workflow

| Step | Rule |
|---|---|
| Branch | `{TASK-ID}/{slug}` e.g. `DOM-001/domain-inventory` |
| PR title | `{TASK-ID} Short title (#N)` |
| Merge | Squash to `main` after CI green |
| WIP | Max 1 issue **In progress** on board |

CI checks on every PR: branch name, SwiftFormat, build, tests.

## Phase 0 — Product contracts

| ID | Title | Est | Status | GitHub |
|---|---|---:|---|---|
| P0-001…005 | Product contracts accepted | — | contract | — |
| MIG-001 | Migration note | — | done | — |

## Phase 1 — Domain

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DOM-001 | Domain inventory from specs | 1d | — | tracked | #1 |
| DOM-002 | Spec-derived test fixtures | 1d | DOM-001 | tracked | #2 |
| DOM-003 | Capture domain + policy tests | 4d | DOM-001 | tracked | #3 |
| DOM-004 | ADR-001 closure | 1d | — | tracked | #4 |

## Phase 2 — Engineering

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| BOOT-001 | App scaffold + folder tree | 2d | — | done | — |
| ENG-001 | Logging facade | 1d | BOOT-001 | done | — |
| ENG-003 | CI quality gates | 2d | BOOT-001 | done | — |
| ENG-004 | Persistence + provisional car | 3d | DOM-003 | tracked | #5 |
| ENG-002 | Analytics boundary | 2d | CB-002 | tracked | #6 |
| ANL-001 | Analytics spike | 2d | ENG-002 | tracked | #7 |

## Road investigations

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| INV-ROAD-001 | Horizon and spacing | 1d | — | tracked | #8 |
| INV-ROAD-002 | Mixed time/mileage | 1d | — | tracked | #9 |
| INV-ROAD-003 | Milestone clustering | 1d | INV-ROAD-001 | tracked | #10 |
| INV-ROAD-004 | Return to current position | 1d | INV-ROAD-001 | tracked | #11 |

## Phase 3 — Car Board

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CB-001 | Provisional car context | 2d | ENG-004 | tracked | #12 |
| CB-002 | Car Board shell + utility layer | 4d | CB-001 | tracked | #13 |
| CB-003 | Notes tile + entry | 2d | CB-002, DOM-003 | tracked | #14 |
| CB-004 | History tile + entry | 2d | CB-002 | tracked | #15 |
| CB-005 | Service tile summary | 3d | CB-002 | tracked | #16 |
| CB-006 | Road projection domain | 4d | DOM-001, INV-ROAD-* | tracked | #17 |
| CB-007 | Road UI | 4d | CB-006, INV-ROAD-* | tracked | #18 |

## Phase 4 — Capture / Pit

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CAP-001 | CaptureInput boundary | 2d | DOM-003 | tracked | #19 |
| CAP-002 | Proposal + confirmation | 3d | CAP-001 | tracked | #20 |
| CAP-003 | Pit Eyes affordance | 2d | CB-002 | tracked | #21 |
| CAP-004 | Pit Capture Surface | 3d | CAP-001, CAP-003 | tracked | #22 |
| CAP-005 | FM interpreter spike (RU) | 5d | CAP-002 | tracked | #23 |
| CAP-006 | Raw-preservation fallback | 2d | CAP-002 | tracked | #24 |
| CAP-007 | End-to-end Remember | 4d | CAP-004–006 | tracked | #25 |

## Phase 5 — Progressive discovery

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DISC-001 | Question value registry | 2d | M4 | tracked | #26 |
| DISC-002 | First high-value question | 3d | DISC-001 | tracked | #27 |
| DISC-003 | Attention cooldown | 2d | DISC-001 | tracked | #28 |
| DISC-004 | Pit semantic motion | 3d | CAP-003 | tracked | #29 |

## Phase 6 — System capture

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| SYS-001 | App Intent investigation | 1d | CAP-007 | tracked | #30 |
| SYS-002 | RememberInPitStopIntent | 2d | SYS-001 | tracked | #31 |
| SYS-003 | App Shortcut | 1d | CAP-007 | tracked | #32 |
| SYS-004 | Widget investigation | 1d | CAP-007 | tracked | #33 |
| SYS-005 | Widget capture slice | 3d | SYS-004 | tracked | #34 |
| SYS-006 | Siri capture slice | 3d | SYS-002 | tracked | #35 |

## Phase 7 — Maintenance intelligence

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| MNT-INT-001 | Maintenance intelligence investigations | 5d+ | M4 | tracked | #36 |

## Legacy

| ID | Title | Status | GitHub |
|---|---|---|---|
| LEG-001 | Tab-bar spike on `legacy/spike` | done | — |

## Pick-up order

```text
DOM-001 → DOM-002 → DOM-003 → ENG-004 → INV-ROAD-* → CB-001…007 → CAP-001…007
```

Deferred after M4: DISC-*, SYS-*, MNT-INT-001, ENG-002, ANL-001.
