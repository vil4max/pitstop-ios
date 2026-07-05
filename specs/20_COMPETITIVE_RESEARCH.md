# Competitive Research

## Purpose

This document compares PitStop with active and relevant vehicle-owner products.

The goal is not to count features mechanically. The primary research question is:

> What mental model does each product teach the owner, and where does PitStop have a meaningfully different product loop?

Research freshness: 2026-07-05.

Public product material and store listings can be incomplete. `Not found` means the capability was not found in reviewed public material; it does not prove the capability does not exist.

## Primary mental model taxonomy

| Mental model | User expectation |
|---|---|
| Tracker | I continuously enter measurable vehicle data and inspect totals/trends. |
| Logbook | I keep a durable chronological record of work and ownership events. |
| Vehicle manager | I manage vehicles, costs, documents, readings, reminders and operational data. |
| Maintenance assistant | The product tells me what maintenance is due or approaching and helps me act. |
| AI mechanic | I ask automotive questions and receive AI-generated advice or diagnosis-like guidance. |
| Contextual car memory | I tell the product an unstructured owner thought; it remembers, classifies and returns it in a useful real-world context. |

A product may support multiple models. `Primary mental model` describes the dominant interaction contract visible in reviewed public material.

PitStop's current hypothesis is `contextual car memory + maintenance assistant`.

## Competitive activity and mental-model matrix

| Product | Primary mental model | Secondary model | Product activity | Research tier | PitStop relevance |
|---|---|---|---|---|---|
| PitStop | Contextual car memory | Maintenance assistant | Prototype / active development | Internal | Product hypothesis |
| CARFAX Car Care | Maintenance assistant | Logbook | Active iOS product | Tier 1 | Strong maintenance-status, service-history and garage benchmark |
| Fuelio | Tracker | Vehicle manager | Active iOS product | Tier 1 | Strong logging, reminders, widget and CarPlay benchmark |
| Drivvo | Vehicle manager | Tracker | Active product | Tier 1 | Broad vehicle-management and odometer workflow benchmark |
| Car Maintenance: Car AI | AI mechanic | Maintenance assistant | Young active iOS product | Tier 1 | AI anti-reference and adjacent experiment |
| Car Maintenance Reminders | Maintenance assistant | Logbook | Active iOS product | Tier 1 | Close benchmark for simple reminders, odometer freshness, records and iCloud |
| LubeLogger | Logbook | Vehicle manager | Very active OSS | Tier 2 | Mandatory domain/data-model teardown |
| AUTOsist | Vehicle manager | Logbook | Active, fleet-oriented | Tier 3 | Inspect selected history, maintenance and document mechanics |
| Simply Auto | Tracker | Vehicle manager | iOS stale; cross-platform maintenance unclear | Archive reference | Historical friction and voice-to-field reference |
| Basic Car Maintenance | Educational sample | — | OSS sample, not product benchmark | Code reference only | SwiftUI organization reference only |

## Why `Primary mental model` matters

A feature matrix can make unlike products appear equivalent.

For example:

```text
reminders = yes
notes = yes
voice = yes
history = yes
```

does not explain the actual product contract.

A tracker asks:

> What data do you want to record?

A logbook asks:

> What happened to the vehicle?

A maintenance assistant asks:

> What service is due?

An AI mechanic asks:

> What automotive question do you want answered?

PitStop should ask, implicitly:

> What is important for me to remember about this car now, and when will it become useful again?

This distinction is more important than feature-count parity.

## Feature comparison

Legend:

- `Yes` — clearly advertised or evidenced in reviewed public material.
- `Partial` — adjacent capability exists, but not the full PitStop use case.
- `Not found` — not found in reviewed public material.
- `Hypothesis` — planned PitStop product hypothesis, not validated.
- `N/A` — not applicable.

| Capability | PitStop | CARFAX | Fuelio | Drivvo | Car AI | Car Maint. Reminders | LubeLogger | Simply Auto |
|---|---|---|---|---|---|---|---|---|
| Maintenance reminders | Hypothesis/current prototype direction | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Odometer-based state | Hypothesis/current prototype direction | Partial | Yes | Yes | Yes | Yes | Yes | Yes |
| Service history | Hypothesis | Yes | Yes | Yes | Yes | Yes | Yes | Partial |
| Expenses | Hypothesis | Not found | Yes | Yes | Yes | Partial | Yes | Yes |
| Multi-vehicle | Deferred / investigate | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Attachments / receipts | Hypothesis | Partial | Yes | Yes | Not found | Yes | Yes | Partial |
| Voice input | Future hypothesis | Not found | Not found | Not found | AI chat/input | Not found | Not found | Yes: voice-to-fill-up values |
| AI automotive chat | No: explicitly not product core | Not found | Not found | Not found | Yes | Not found | Not found | Not found |
| Contextual owner Notes | Hypothesis | Not found | Not found | Not found | Not found | Not found | Partial/planner-adjacent | Not found |
| Context recall by situation | Hypothesis | Not found | Not found | Not found | Not found | Not found | Not found | Not found |
| Typed draft from unstructured thought | Future hypothesis | Not found | Not found | Not found | Partial/unclear | Not found | Not found | Not found |
| Practical service composition | Hypothesis | Partial/unclear | Not found | Not found | Not found | Not found | Partial/planner-adjacent | Not found |
| Partial service completion resets only confirmed cycles | Hypothesis | Not found | Not found | Not found | Not found | Not found | Investigate | Not found |
| CarPlay | Investigate | Not found | Yes | Not found | Not found | Not found | N/A | Not found |
| iCloud / Apple-native sync | Planned | Not found | iCloud Drive backup | Not found | Not found | Yes | N/A | Multi-device sync advertised |

## Product-by-product analysis

### CARFAX Car Care

Official:
- https://www.carfax.com/Service/
- https://apps.apple.com/us/app/carfax-car-care/id552472249

Primary mental model: `maintenance assistant`.

CARFAX is a strong benchmark for customized maintenance status, service alerts, service history and a multi-vehicle garage. Its current App Store history shows active iOS delivery and an iOS 26 visual update.

PitStop should not compete by merely adding a dashboard with oil, tire and filter cards. CARFAX already communicates that model at scale.

Research question:

> Can PitStop make owner-specific memory and service composition useful where a standardized service dashboard cannot?

### Fuelio

Official:
- https://www.fuel.io/
- https://apps.apple.com/us/app/fuelio-gas-log-mpg-tracker/id1487753318

Primary mental model: `tracker`.

Fuelio's public App Store material centers on fill-ups, fuel prices, mileage, maintenance and vehicle costs, and advertises CarPlay support.

It is a strong benchmark for low-friction repetitive logging and automotive utility surfaces.

PitStop should avoid becoming a dashboard-heavy fuel/cost tracker.

Research questions:
- How quickly can a user update mileage?
- What is useful on CarPlay?
- How do reminders and widgets reduce app-open friction?

### Drivvo

Official:
- https://www.drivvo.com/en/
- https://apps.apple.com/ua/app/drivvo-vehicle-management/id1206041425

Primary mental model: `vehicle manager`.

Drivvo manages refueling, maintenance, costs and readings. Current public release material includes a dedicated odometer Readings module and vehicle-history transfer.

It is a strong benchmark for breadth and structured vehicle administration.

PitStop should not chase Drivvo feature parity.

Research question:

> Can PitStop create more value from less structured input and a narrower owner workflow?

### Car Maintenance: Car AI

Official:
- https://apps.apple.com/us/app/car-maintenance-car-ai/id6744633450

Primary mental model: `AI mechanic`.

The product combines vehicle management with a per-car AI assistant. Public version history also mentions suggested maintenance schedules that can be saved as reminders.

This is an important anti-reference.

PitStop is not:

```text
open chat
→ ask mechanic question
→ receive AI answer
```

PitStop's AI boundary is:

```text
unstructured owner thought
→ typed draft
→ validation
→ user confirmation
→ deterministic product state
```

Research question:

> Does AI improve durable owner memory, rather than merely generate automotive answers?

### Car Maintenance Reminders

Official:
- https://apps.apple.com/us/app/car-maintenance-reminders/id1617869280

Primary mental model: `maintenance assistant`.

This is a small but close product benchmark. Public App Store material emphasizes service reminders, mileage updates, records with photos and iCloud sync.

A public review specifically describes the shared-car odometer freshness problem: when two people share a car, relying on every fill-up to update mileage can become inaccurate. This maps directly to PitStop's unresolved odometer-freshness investigation.

Research questions:
- How is weekly odometer prompting timed?
- How much friction exists in creating a custom maintenance reminder?
- How are completed maintenance items represented in history?
- How is iCloud behavior communicated to the user?

### LubeLogger

Official:
- https://lubelogger.com/
- https://github.com/hargata/lubelog
- https://github.com/hargata/lubelog/releases

Primary mental model: `logbook`.

LubeLogger is an active OSS reference with frequent 2026 releases. It should be treated as a mandatory domain teardown, not merely a UI competitor.

Research targets:
- reminder semantics;
- recurring interval representation;
- planner/to-do model;
- service records;
- vehicle history;
- partial completion semantics;
- data-model boundaries between reminder, plan and completed record.

Do not copy its architecture mechanically. It is a web/self-hosted product with different platform constraints.

### AUTOsist

Official:
- https://autosist.com/
- https://apps.apple.com/us/app/autosist-fleet-management-app/id897916520

Primary mental model: `vehicle manager`.

The current product is strongly fleet/B2B-oriented. Public release material includes vehicle/asset status, user permissions, factory recommended maintenance schedules and recalls.

Use as a selected mechanics benchmark, not as a PitStop product-direction benchmark.

### Simply Auto

Official:
- https://simplyauto.app/
- https://apps.apple.com/us/app/simply-auto-mileage-tracker/id893278325

Primary mental model: `tracker`.

The reviewed iOS App Store listing shows version `50.1.1` as approximately four years old. Therefore it is not a current iOS UX or platform benchmark.

Important correction: its advertised voice capability is voice entry for fill-up values. That is not evidence of:

```text
unstructured owner thought
→ contextual typed draft
```

Simply Auto remains useful as a historical example of tracker-first product design and voice-to-field friction reduction.

## PitStop strengths — current hypotheses

### 1. Contextual car memory

PitStop can potentially model owner thoughts that do not naturally belong in a maintenance form:

- replace wipers before winter;
- ask the car wash to clean the engine bay;
- investigate a strange smell in the cabin;
- buy new floor mats;
- buy cleaning chemicals;
- revisit film/wrap work.

The existing seeded film/wrap and floor-mat cases are product-discovery evidence.

### 2. Contextual recall

The product hypothesis is not only storing a Note.

It is:

```text
remember
→ classify
→ preserve
→ surface in useful context
```

Example:

```text
car wash context
→ show active car-wash Notes
```

This must be validated before AI capture is treated as a differentiator.

### 3. Deterministic maintenance state

Independent maintenance cycles remain deterministic domain state.

LLM output must not own:
- due state;
- severity;
- cycle reset;
- service completion.

### 4. Practical service composition

Owners commonly combine nearby work into one service visit.

PitStop can potentially compose a practical proposal while preserving independent operation cycles and allowing partial completion.

### 5. Natural capture as a friction reducer

Voice or natural-language input is not differentiation by itself.

The stronger hypothesis is:

> PitStop converts an unstructured owner thought into persistent contextual memory and later reconnects confirmed real-world actions to deterministic vehicle state.

## PitStop weaknesses and risks

| Risk | Why it matters | Current response |
|---|---|---|
| Contextual Notes may be niche | The core mental model may not create repeat use | Validate with five-user beta |
| Context classification may be wrong | Wrong recall timing destroys trust | Typed draft + confirmation; measure edits |
| Odometer freshness is unresolved | Maintenance state becomes stale | Dedicated investigation; benchmark shared-car workflows |
| Manufacturer maintenance data is complex | Market/engine/gearbox/regime differences | One verified Arteon profile + manual policy in P0 |
| Product can become architecture-heavy | Learning-lab goals can delay validation | Demand-driven packages and P0 core-loop filter |
| AI can become a gimmick | Chat does not equal durable product value | Non-agent-first typed-draft boundary |
| Expenses/history can pull product toward tracker parity | Feature breadth dilutes differentiation | Only implement when supporting a core loop |
| CarPlay can become speculative scope | Platform surface before proven use case | Investigate after core workflow evidence |

## Research priority

### Tier 1 — install and scenario-test

1. CARFAX Car Care
2. Fuelio
3. Drivvo
4. Car Maintenance: Car AI
5. Car Maintenance Reminders

Run the same scenarios:

```text
A. "Replace wipers before winter."
B. "At the car wash, ask them to clean the engine bay."
C. "Car wash today, 500 UAH."
D. Update odometer.
E. Oil, DSG and AWD work become due near each other.
F. Complete only part of a proposed service visit.
```

Measure:
- taps;
- forms/screens;
- required fields;
- whether the product's mental model matches the user's thought;
- whether the information can be retrieved later in context;
- whether completion updates deterministic state correctly.

### Tier 2 — domain teardown

LubeLogger.

Produce a separate domain mapping:

```text
LubeLogger concept
→ semantics
→ PitStop equivalent
→ useful lesson
→ do not copy because...
```

### Tier 3 — selected mechanics only

AUTOsist.

### Archive reference

Simply Auto.

### Code reference only

Basic Car Maintenance.

## Current competitive conclusion

PitStop should not compete on the number of vehicle-management features.

The strongest current differentiation hypothesis is:

> PitStop is contextual car memory with deterministic maintenance intelligence.

The competitive boundary is:

```text
Tracker
→ records measurements

Logbook
→ records history

Vehicle manager
→ organizes vehicle operations

Maintenance assistant
→ tells the owner what service is due

AI mechanic
→ answers automotive questions

PitStop
→ remembers owner-specific car context,
   returns it when useful,
   and connects confirmed actions
   to deterministic maintenance state
```

This is a hypothesis until beta evidence proves contextual recall has real value.

## Official research links

- LubeLogger — https://lubelogger.com/
- LubeLogger GitHub — https://github.com/hargata/lubelog
- LubeLogger Releases — https://github.com/hargata/lubelog/releases
- Drivvo — https://www.drivvo.com/en/
- Simply Auto — https://simplyauto.app/
- CARFAX Car Care — https://www.carfax.com/Service/
- Fuelio — https://www.fuel.io/
- AUTOsist — https://autosist.com/
- Car Maintenance: Car AI — https://apps.apple.com/us/app/car-maintenance-car-ai/id6744633450
- Car Maintenance Reminders — https://apps.apple.com/us/app/car-maintenance-reminders/id1617869280
- Basic Car Maintenance GitHub — https://github.com/mikaelacaron/Basic-Car-Maintenance
