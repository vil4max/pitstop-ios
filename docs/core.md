# PitStop — core

Status: approved (2026-09-16). Details live in
[requirements/product-charter.md](requirements/product-charter.md),
[requirements/product-overview.md](requirements/product-overview.md), and
[decisions/0004-product-design-rationale.md](decisions/0004-product-design-rationale.md).

## Goal

A smart driver's journal and contextual memory for a car: PitStop remembers
the car with the driver, starting from the driver's concerns, habits, notes, and
real maintenance behaviour rather than a complete vehicle profile. Maintenance
is one domain inside the product, not its identity.

Core loop: save a thought → find and use it → record what actually happened →
understand what matters next.

## Language

| Term | Meaning |
|---|---|
| Remember | Capability that preserves a thought first and may propose structure second |
| Note | A saved thought or intention; original wording is authoritative; archiving is not performed work |
| History | Recorded facts about what actually happened to the car |
| Service | Maintenance state derived from policies and confirmed completions |
| Road | Projection of known plans and deterministic maintenance state onto the nearest milestones; not a planner or map |
| Car Board | Summary surface with entrances to the owned surfaces; not a source of truth |
| Car context | One provisional car, progressively corrected; placeholders are not vehicle facts |
| Proposal | Typed meaning suggested by AI or rules; validated by domain code before any mutation |
| Pit | Optional helper for capture, clarification, and progressive discovery; not navigation, storage, or chat |
| Unknown | A valid state; never replaced by invented facts |

## Priorities (higher wins on conflict)

- P1 Raw user meaning is never discarded; stored data can be inspected and corrected.
- P2 Value before profile completion: no auth, form, or setup before first value.
- P3 AI proposes; deterministic domain code decides, and wins wherever it solves the problem. The app stays useful without AI and without Pit.
- P4 Product core before future intelligence: no runtime AI until the core is validated (current gate: [PROJECT_STATUS.md](../PROJECT_STATUS.md)).
- P5 Native Apple patterns by default; sparse UI still looks intentional.

## Constraints

- C1 One car context per user in the first slice.
- C2 Unknown data stays unknown until the user supplies or confirms it, or deterministic logic derives it safely; never inferred by a model or from locale alone.
- C3 Questions come one at a time and only when the answer unlocks near-term value; Pit may interrupt only for measurable value.
- C4 All capture sources use one Capture Pipeline; the source never selects the domain operation, and AI never writes persistence directly.
- C5 Only confirmed completed work resets maintenance cycles or enters History; unperformed work stays unchanged.

## Non-goals (first slice)

Not a product identity (permanent): AI mechanic, diagnostic scanner, dealership
portal, garage manager, maintenance database UI, AI-first app.

Diagnostics, health score, predictive failure detection, full fleet management,
mandatory cloud account, generic chatbot, complete manufacturer database,
VIN-first setup, custom dashboard builder, user-resizable tiles, CarPlay before
investigation, AI-generated maintenance truth.
