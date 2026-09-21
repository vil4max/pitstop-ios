# Work Plan

**Status:** Active (unfrozen 2026-09-16); see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Next task:** MNT-INT-001 (DOM-004 implemented, ADR 0020; CAP-005 needs a physical device for the Foundation Models spike)  
**Board:** deleted 2026-09-21 at the owner's request. GitHub Project #2 had lost its cards when the pre-public repository and its issues were deleted (ADR 0014); the `#N` column below refers to those deleted issues  
**Backlog:** this plan and `docs/tasks/full-backlog-delivery.md` are the source of truth; specs stay contracts  
**WIP limit:** 1 implementation task in **In progress** (solo) — backlog visibility does not mean parallel work  
**Estimates:** ideal focused dev days  
**Process:** [`../engineering/agent-loop-and-gitflow.md`](../engineering/agent-loop-and-gitflow.md)

## Milestones

| Milestone | Exit criteria | Status | Cumulative est. |
|---|---|---|---:|
| M0 | Work plan + board + local verification | done | — |
| M1 | `legacy/spike`; BOOT-001; ENG-001; ENG-003 | done | ~8d |
| M2 | DOM-003 tests; INV-ROAD decisions | implemented on stacked branches, unmerged | ~11d |
| M3 | Car Board tiles + Road | implemented on stacked branches, unmerged | ~21d |
| M4 | Remember end-to-end | planned | ~21d |

Calendar solo multiplier: ×1.4–1.6 → M4 ≈ 12–16 weeks.

M0/M1 completion records are historical. ENG-003 is reopened for the current
agent-loop setup. Hosted CI was retired and later replaced by the shared Runtime pipeline on a
GitHub-hosted runners (ADR 0013, 0014); branch protection remains a proposal, not an
active guarantee.

## Feature readiness vs milestone completion

The [product charter](../requirements/product-charter.md#product-loop-and-feature-responsibilities)
defines useful features; task rows below schedule implementation slices. **M3 is
a domain and screen foundation. M4 is the Remember end-to-end checkpoint.**
A finished tile or navigation entry does not establish the complete user journey.

| Capability | Evidence required beyond a tile or shell |
|---|---|
| Notes | Save a thought, reopen the app, find and read it, then correct or archive it without requiring AI classification. |
| History | Read persisted vehicle events created through supported domain commands; intentions and unconfirmed work are not events. |
| Service | Derive status from effective policies and confirmed operations, handle missing baselines honestly, and reset only completed operations. |
| Road | Project eligible facts and plans under the agreed horizon rules; show unknown or no-known-milestones states instead of fabricated data. |
| Remember | CAP-007 proves capture → policy → command → persistence → visible result. Raw saving works without a model; interpreted capture obeys the same validation and confirmation boundary. |

The current tile-task estimates are not estimates for every behaviour above.
Before implementing an owning task, reconcile its acceptance criteria and domain
dependencies with the linked contracts; report missing scope for owner agreement
instead of silently expanding a tile task. This clarification does not change
task IDs, estimates, dependencies, milestone order, or the next task. CAP-* stays
in M4; raw preservation is both a normal Remember mode and the safe fallback.

## Status legend

| Status | Meaning |
|---|---|
| `contract` | Accepted spec; no issue |
| `done` | Shipped; issue closed |
| `next` | Next task or milestone; not yet in progress |
| `tracked` | GitHub issue in backlog or active |
| `planned` | Future milestone; no active work |
| `deferred` | Later phase; issue exists, low priority |

## Git workflow

| Step | Rule |
|---|---|
| Branch | `{TASK-ID}/{slug}` e.g. `DOM-001/domain-inventory` |
| PR title | `{TASK-ID} Short title (#N)` |
| Merge | Squash to `main` after local verification and review |
| WIP | Max 1 issue **In progress** on board |

Implementation verification: local `just verify` (formatting, lint, build, tests).
GitHub Actions adds a tests run on GitHub-hosted runners (ADR 0014).
See `../engineering/quality-and-ci.md`.

## Phase 0 — Product contracts

| ID | Title | Est | Status | GitHub |
|---|---|---:|---|---|
| P0-001…005 | Product contracts accepted | — | contract | — |
| MIG-001 | Migration note | — | done | — |

## Phase 1 — Domain

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DOM-001 | Domain inventory from specs | 1d | — | done | #1 |
| DOM-002 | Spec-derived test fixtures | 1d | DOM-001 | done | #2 |
| DOM-003 | Capture domain + policy tests | 4d | DOM-001 | implemented on branch, unmerged | #3 |
| DOM-004 | ADR-001 closure | 1d | — | implemented (ADR 0020) | #4 |

## Phase 2 — Engineering

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| BOOT-001 | App scaffold + folder tree | 2d | — | done | — |
| ENG-001 | Logging facade | 1d | BOOT-001 | done | — |
| ENG-003 | Local quality gates (shared CI: ADR 0013) | 2d | BOOT-001 | tracked | — |
| ENG-004 | Persistence + provisional car | 3d | DOM-003 | implemented on branch, unmerged | #5 |
| ENG-002 | Analytics boundary | 2d | CB-002 | tracked | #6 |
| ANL-001 | Analytics spike | 2d | ENG-002 | tracked | #7 |

## Road investigations

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| INV-ROAD-001 | Horizon and spacing | 1d | — | decided in ADR 0008, unmerged | #8 |
| INV-ROAD-002 | Mixed time/mileage | 1d | — | decided in ADR 0008, unmerged | #9 |
| INV-ROAD-003 | Milestone clustering | 1d | INV-ROAD-001 | decided in ADR 0008, unmerged | #10 |
| INV-ROAD-004 | Return to current position | 1d | INV-ROAD-001 | decided in ADR 0008, unmerged | #11 |

## Phase 3 — Car Board

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CB-001 | Provisional car context | 2d | ENG-004 | implemented on branch, unmerged | #12 |
| CB-002 | Car Board shell + utility layer | 4d | CB-001 | implemented on branch, unmerged | #13 |
| CB-003 | Notes tile + entry | 2d | CB-002, DOM-003 | implemented on branch, unmerged | #14 |
| CB-004 | History tile + entry | 2d | CB-002 | implemented on branch, unmerged | #15 |
| CB-005 | Service tile summary | 3d | CB-002 | implemented on branch, unmerged (includes the engine; see ADR 0010) | #16 |
| CB-006 | Road projection domain | 4d | DOM-001, INV-ROAD-* | implemented on branch, unmerged | #17 |
| CB-007 | Road UI | 4d | CB-006, INV-ROAD-* | implemented on branch, unmerged | #18 |

## Phase 4 — Capture / Pit

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| CAP-001 | CaptureInput boundary | 2d | DOM-003 | implemented on branch, unmerged | #19 |
| CAP-002 | Proposal + confirmation | 3d | CAP-001 | done on main | #20 |
| CAP-003 | Pit Eyes affordance | 2d | CB-002 | done on main | #21 |
| CAP-004 | Pit Capture Surface | 3d | CAP-001, CAP-003 | done on main | #22 |
| CAP-005 | FM interpreter spike (RU) | 5d | CAP-002 | tracked | #23 |
| CAP-006 | Raw-preservation fallback | 2d | CAP-002 | implemented (ADR 0015) | #24 |
| CAP-007 | End-to-end Remember | 4d | CAP-004–006 | implemented (`RememberEndToEndTests`) | #25 |

## Phase 5 — Progressive discovery

| ID | Title | Est | Deps | Status | GitHub |
|---|---|---:|---|---|---|
| DISC-001 | Question value registry | 2d | M4 | implemented (ADR 0016) | #26 |
| DISC-002 | First high-value question | 3d | DISC-001 | implemented (ADR 0017) | #27 |
| DISC-003 | Attention cooldown | 2d | DISC-001 | implemented (ADR 0018) | #28 |
| DISC-004 | Pit semantic motion | 3d | CAP-003 | implemented (ADR 0019) | #29 |

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

## Backlog vs active work

| Layer | Role |
|---|---|
| `work-plan.md` | Horizon, estimates, deps, issue links |
| GitHub Project #2 | Board/Table — see all tasks and status |
| GitHub issues #1–#36 | Acceptance detail per task |
| Specs `product-charter`, `car-board-screen`, `road-domain-and-ui`, `pit-behavior-and-motion`, `capture-pipeline`, `bottom-utility-layer`, `screen-grammar`, `capture-pipeline` | Product contracts — not replaced by issues |

Create issues upfront for the full horizon. Move only **one** card to **In progress** at a time. On issue close: row → `done` in this file.
