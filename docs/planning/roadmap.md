# Atomic Development Roadmap

**Status:** phase index — open work lives in [`work-plan.md`](work-plan.md)  
**Project state:** Active — see [`../PROJECT_STATUS.md`](../../PROJECT_STATUS.md)  
**Rule:** the current product is `main`; the pre-greenfield tab-bar spike is not kept in this repository (ADR 0014)

## Phase index

| Phase | Scope | Status |
|---|---|---|
| 0 | Product contracts | accepted as contracts; requirements await owner approval |
| 1 | Domain inventory + capture boundary (DOM-*) | delivered |
| 2 | Engineering bootstrap (BOOT-001, ENG-*, ANL-001) | delivered |
| — | Road investigations (INV-ROAD-*) | decided in ADR 0008 |
| 3 | Car Board vertical slice (CB-*) | delivered |
| 4 | Pit and Remember (CAP-*) | delivered; CAP-005 off by default (ADR 0027) |
| 5 | Progressive discovery (DISC-*) | delivered |
| 6 | System capture (SYS-*) | delivered through SYS-006; SYS-007 planned |
| 7 | Maintenance intelligence (MNT-INT-001) | investigated; follow-ups planned in the work plan |

## V2 / deferred

- Car Board drag and drop
- Configurable tile order
- Richer Expenses and insurance tile
- Expanded manufacturer intelligence
- CarPlay if validated

## Stop conditions

Pause and return to investigation if:

- Car Board cannot communicate value with sparse data
- Road is decoration only
- Remember does not reduce capture friction
- Users cannot find captured information
- Pit is perceived as required navigation
- Semantic classification creates unsafe mutation pressure
- Manufacturer data becomes necessary before product value exists
