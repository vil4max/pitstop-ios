# PitStop — Project Status

**Project State:** Frozen  
**Reason:** Career and interview priority  
**Last freeze preparation:** documentation and architecture preservation (no runtime changes)

---

# Career proof product loop

**Role:** this repository is the career proof product for the private target:

> AI-assisted Product Engineer able to design, develop, deploy, and maintain a modern product.

**Loop to complete after unfreeze (one product, not three pets):**

1. **Design** — owner-formulated problem / MVP (charter: [`specs/01_PRODUCT_CHARTER.md`](specs/01_PRODUCT_CHARTER.md)).
2. **Develop** — AI-assisted delivery with human review (agents as engineering workflow).
3. **Deploy** — ship a usable build (TestFlight / App Store as applicable).
4. **Maintain** — 1–2 months of post-ship iteration with metrics and user feedback.

**Ordering constraint (unchanged):** complete the product baseline through M3 before runtime AI features (`Remember` / Foundation Models / CAP-*). Agent-assisted coding during baseline work is a workflow choice, not early AI product scope.

**Career upgrade gate (lives in Profile/career, not here):** public phrasing `Senior iOS + AI Product Engineer` stays blocked until shipped/production-grade AI feature evidence is recorded in `career.md`.

Local agent visibility: root `AGENTS.md` (gitignored / machine-local).

---

# Project Phase

- Architecture Complete
- Documentation Stable
- Implementation Paused
- Product Baseline Pending
- AI Deferred

---

## Freeze rules

Allowed:

- documentation
- architecture clarification
- terminology cleanup
- specification refactoring

Not allowed:

- runtime AI
- provider integration
- prompt engineering
- evaluation implementation
- feature implementation

---

## Product baseline (resume definition)

“Complete the product baseline before AI” means reach a usable greenfield product on `main` through **M3** in [`specs/38_WORK_PLAN.md`](specs/38_WORK_PLAN.md):

- domain fixtures and capture-boundary tests (DOM-*)
- persistence for provisional car context (ENG-004)
- Car Board tiles wired to real domain projections
- Road projection and UI

**Remember / Capture / Foundation Models (M4+, CAP-*) stay deferred until that baseline is useful without AI.**

Open after unfreeze: DOM-002.

---

## Current implementation status

Source of truth for what exists on `main`: [`specs/39_DOMAIN_INVENTORY.md`](specs/39_DOMAIN_INVENTORY.md).

| Area | Status on `main` |
|---|---|
| Product contracts / specs | Present and authoritative under `specs/` |
| Provisional car context | Partial (`ProvisionalCarContext`) |
| Car Board | Placeholder UI |
| Capture / Remember pipeline | Not started (intentional; after product baseline) |
| Intelligence / AI runtime | Not started (intentionally deferred) |
| Maintenance engine | Not on `main` (legacy on `legacy/spike` only) |
| Persistence | Intentionally deferred to ENG-004 |
| Notes / Service / History / Road | Not started (product baseline work) |

AI and Remember are specified, not implemented. Product baseline remains higher priority than AI.

---

# Resume Checklist

Recommended order:

1. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) (this file) — including Career proof product loop
2. [`specs/README.md`](specs/README.md)
3. [`specs/01_PRODUCT_CHARTER.md`](specs/01_PRODUCT_CHARTER.md)
4. [`specs/39_DOMAIN_INVENTORY.md`](specs/39_DOMAIN_INVENTORY.md)
5. [`specs/41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](specs/41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md)
6. [`specs/40_AI_ENGINEERING_ROADMAP.md`](specs/40_AI_ENGINEERING_ROADMAP.md)

Then open behavioural owners as needed:

- Capture: `34_CAPTURE_PIPELINE_SPEC.md`
- AI runtime: `04_AI_ARCHITECTURE.md`
- Car Board / Road / Pit: `31`, `32`, `33`
- Work plan: `38_WORK_PLAN.md`
- Full map: `00_DOCUMENTATION_INDEX.md`

Do not resume AI implementation first.

Complete the product baseline before any AI work.

---

## Ownership reminder

| Document | Answers |
|---|---|
| Root `README.md` | Repository entry point |
| `PROJECT_STATUS.md` | Current project state / freeze / resume |
| `01_PRODUCT_CHARTER.md` | Product contract (what) |
| `04_AI_ARCHITECTURE.md` | Runtime AI contract |
| `34_CAPTURE_PIPELINE_SPEC.md` | Capture / Remember contract |
| `39_DOMAIN_INVENTORY.md` | Implementation snapshot |
| `40_AI_ENGINEERING_ROADMAP.md` | Deferred AI direction |
| `41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md` | Architectural / product reasoning (why) |
| `38_WORK_PLAN.md` | Executable backlog |

Do not create parallel sources of truth. Cross-reference owners instead of duplicating them.

---

## Resume rule

Do not resume AI implementation first.

Complete the product baseline before any AI work.
