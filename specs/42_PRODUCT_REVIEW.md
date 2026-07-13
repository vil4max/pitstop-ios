# PitStop — Idea Validation & Product Review

**Status:** Mandatory product process  
**Purpose:** Continuously validate ideas against PitStop's core value before implementation  
**Owners:** Product decisions stay in [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md) and [`41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md). This document owns the review ritual and checklist.

This document is part of the product development process.

Every new feature, surface, or major behaviour change must pass Product Review before implementation work begins.

---

## Core principle

Do not assume an idea is good because it sounds exciting.

Every feature must answer difficult product questions before implementation.

The goal is not to kill ideas.

The goal is to understand them.

---

## Guiding philosophy

PitStop should not become "an app for managing a car."

PitStop should become:

> The trusted memory of the relationship between a driver and their vehicle.

Aligned product statements:

> PitStop is a smart driver's journal and contextual memory for a car.

> PitStop remembers the car with the driver.

Every feature should make that memory richer, more useful, and more valuable over time.

If a feature does not strengthen that vision, it should be questioned before implementation.

---

## When Product Review is required

Run Product Review when proposing:

- a new user-facing feature or screen;
- a new capture / Pit / Remember behaviour;
- a retention, growth, or monetisation idea;
- expansion beyond the current product boundary;
- anything that adds forms, notifications, setup, or ongoing user work.

Skip a full review only for:

- pure bug fixes;
- internal refactors with no behaviour change;
- documentation-only work;
- already-accepted items from an owning contract (implement as specified).

For feature issues and epics, complete the Feature Review Template below and link the filled answers in the issue or task.

---

## Product Review Checklist

### 1. Core Job To Be Done

What job is the user hiring PitStop to do?

Avoid generic answers like:

- manage my car;
- keep notes.

Prefer concrete jobs like:

> Help me remember things about my car before forgetting costs me time or money.

Charter JTBD owners live in [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md). Every feature must strengthen at least one of them:

- remember something with minimal friction;
- understand the car context at a glance;
- contextual memory when it matters;
- maintenance orientation without false urgency.

### 2. Trigger

What real-world event causes the user to open PitStop?

Examples:

- refueled;
- serviced the car;
- heard a strange noise;
- warning light appeared;
- buying parts;
- preparing for a trip;
- selling the vehicle.

PitStop should be event-driven rather than record-driven.

### 3. Habit Formation

How often will a normal user naturally return?

Avoid features used only every six months.

Prefer workflows that happen weekly or monthly.

Examples:

- fuel;
- maintenance;
- expenses;
- quick AI questions grounded in car memory;
- checking reminders / Road.

### 4. Magic Moment

What is the moment where the user immediately understands why PitStop exists?

Example:

User:

> Something is rattling again.

Pit:

> A similar sound was recorded eight months ago after 94,000 km. The issue was the stabilizer link.

This memory-based experience is the product magic.

### 5. Why not ChatGPT?

For every feature ask:

> Why can't a generic AI assistant replace this?

PitStop's advantage should come from accumulated personal vehicle memory:

- history;
- mileage;
- maintenance;
- expenses;
- recurring issues;
- context.

The moat is accumulated context, not AI itself.

Pit remains a helper for capture, clarification, and progressive discovery — not a generic chatbot. See Pit boundary in [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md).

### 6. Retention

Why will users still use PitStop one year later?

Look for long-term value accumulation.

Every interaction should make future interactions more valuable.

### 7. Moat

What becomes harder for competitors to copy over time?

Possible moat:

- vehicle history;
- maintenance timeline;
- personal driving context;
- AI memory grounded in that history;
- accumulated knowledge of this driver–car relationship.

Not:

- UI;
- LLM;
- technology stack.

### 8. Deletion Test

Why would users uninstall PitStop?

Potential reasons:

- too many forms;
- too much setup;
- feels like enterprise software;
- annoying notifications;
- no immediate value.

Every feature should reduce these risks, not add to them.

Align with product-core failure criteria in [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md).

### 9. Explicit Non-Goals

Keep a growing list of things PitStop intentionally will **not** become.

Current boundaries (first slice + long-term posture):

- social network;
- marketplace;
- navigation app;
- OBD scanner / vehicle diagnostics product;
- fleet management;
- repair marketplace;
- dealership portal;
- generic chatbot;
- AI mechanic by default;
- health-score / predictive-failure product;
- VIN-first setup funnel;
- custom dashboard builder.

Slice-specific non-goals remain owned by [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md). When Product Review rejects a category permanently, add it here and mirror a short note in the charter if it changes product identity.

Clear boundaries improve product quality.

### 10. Success Metric

Avoid vanity metrics (downloads alone, chat message count, feature adoption without outcome).

Define product success as moments where accumulated memory helps users.

Examples:

- user benefits from a previous record;
- user avoids duplicate work;
- user remembers maintenance at the right time;
- user saves money or time because PitStop remembered something.

---

## Feature Review Template

Copy this into the issue, investigation, or task before implementation.

```text
## Product Review

**Idea:** ...
**Date:** ...
**Decision:** Pass / Pass with constraints / Defer / Reject

### Answers

1. User problem:
2. JTBD supported (link to charter job):
3. Trigger (real-world event):
4. Natural frequency of use:
5. Retention effect (why return later?):
6. Memory graph: does this enrich trusted car memory?
7. Why not ChatGPT / generic AI?
8. Moat effect:
9. Fits long-term vision (trusted driver–vehicle memory)? Yes / No — why:
10. New complexity introduced (UX, domain, AI, ops):
11. Simpler alternative considered:

### Checklist gates

- [ ] Strengthens core JTBD
- [ ] Has a real-world trigger
- [ ] Habit frequency is acceptable (not once-per-year only, unless strategic)
- [ ] Magic moment is clear or clearly enabled later
- [ ] Advantage is personal vehicle memory, not generic AI
- [ ] Improves one-year retention story
- [ ] Strengthens moat (history / context), not UI/LLM novelty
- [ ] Deletion risks do not increase
- [ ] Outside explicit non-goals
- [ ] Success metric is memory-outcome based, not vanity

### Constraints if Pass with constraints

- ...

### If Reject or Defer

Reason:
Safer alternative:
```

---

## Process placement

```text
Idea
  ↓
Product Review (this document)
  ↓
Investigation / Epic (if needed)
  ↓
Task from 16_TASK_TEMPLATE.md
  ↓
Implementation
```

Related process docs:

- [`01_PRODUCT_CHARTER.md`](01_PRODUCT_CHARTER.md) — product statement, JTBD, non-goals, success/failure;
- [`16_TASK_TEMPLATE.md`](16_TASK_TEMPLATE.md) — implementation task shape after review passes;
- [`24_PROJECT_MANAGEMENT_AND_GITFLOW.md`](24_PROJECT_MANAGEMENT_AND_GITFLOW.md) — issue / PR flow;
- [`41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md) — record why decisions stuck;
- [`09_INVESTIGATIONS.md`](09_INVESTIGATIONS.md) — open questions that may need evidence before Pass.

Rejected or deferred ideas with lasting product meaning should leave a short note in [`41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md) so the same idea is not rediscovered as "obviously good."

---

## Review cadence

- **Per idea:** before any implementation branch for a new feature.
- **Periodic:** when resuming the project from freeze, re-read this document and re-check the active roadmap against the checklist.
- **After major ships:** run Deletion Test and Retention questions against what actually shipped.

Do not treat a past Pass as permanent permission to expand scope without re-review.
