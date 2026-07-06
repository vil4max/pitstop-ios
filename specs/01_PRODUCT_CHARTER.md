# Product Charter

## Product statement

> PitStop is a smart driver's journal and contextual memory for a car.

> PitStop remembers the car with the driver.

The product starts from the driver's concerns, habits, notes, and real maintenance behaviour. Exact vehicle intelligence may be added progressively.

PitStop is not an AI mechanic, diagnostic scanner, dealership portal, or maintenance database UI.

## Primary mental model

**Contextual car memory.**

Supporting mental models:
- driver's journal;
- lightweight service book;
- maintenance organiser;
- car history.

Maintenance is a domain inside the product. It is not the whole product identity.

## Primary jobs to be done

### Remember something with minimal friction

> When I remember something about my car, I want to save it immediately without deciding which database form it belongs to.

Success:
- capture is reachable quickly;
- voice is optional, not mandatory;
- short choices replace typing where practical;
- raw meaning is preserved;
- structured meaning is proposed safely;
- user can inspect and correct stored data.

Failure:
- capture begins with a form-type picker;
- the user must type ordinary structured facts;
- AI writes directly to persistence;
- ambiguous meaning is silently guessed.

### Understand the car context at a glance

> When I open PitStop, I want to see my car, what matters next, and the memory surfaces I actually use.

Success:
- Car Board is useful with sparse data;
- the car remains visually primary;
- Road exposes meaningful future milestones;
- tiles provide information before tap;
- Notes, Service, and History are obvious entrances.

Failure:
- Home is a menu of empty icon tiles;
- the first screen is dominated by setup;
- unknown vehicle data creates broken UI;
- the user must learn a custom navigation system.

### Contextual memory

> When I arrive at a relevant place or situation, I want to find what I wanted to remember about the car.

Success:
- notes preserve original wording;
- context can be inferred or attached without mandatory tag management;
- interpretation failure never loses the raw memory.

Failure:
- user manually maintains a taxonomy;
- AI rewriting replaces source meaning;
- captured information disappears into an unclear feature.

### Maintenance orientation

> When maintenance matters, I want a calm, understandable view of what is approaching and what happened before.

Success:
- deterministic maintenance state;
- no false vehicle-health claims;
- independent operation cycles;
- user intervals may override defaults;
- meaningful maintenance events can become Road milestones.

Failure:
- red is used for ordinary reminders;
- AI invents urgency;
- manufacturer defaults are presented without provenance;
- all maintenance is collapsed into one scalar health score.

## First-launch contract

Opening PitStop implies a likely car context but does not require a completed vehicle profile.

The app opens directly into a usable Car Board with a provisional context:

```text
My New Car
0 km
vehicle details unknown
```

This is a provisional product context, not a factual claim that the user bought a new vehicle.

The app must not require:
- authentication;
- VIN;
- make/model;
- engine;
- fuel type;
- gearbox;
- a multi-step onboarding flow.

Progressive discovery asks one short question at a time only when the answer unlocks near-term value.

There is no required binary `onboarding_completed` product state.

## Progressive discovery

Preferred interactions:
- Yes / No;
- 2–4 answer slots;
- `Other`;
- `I don't know`;
- optional voice/text when the user explicitly wants to tell more.

The system may use locale or App Store region to order likely choices. It must never silently infer vehicle truth from region.

Every discovery question must have:
- value unlocked;
- domain concept affected;
- behaviour changed;
- deferral path.

Do not classify the user as `geek` or `beginner`. Infer desired detail depth from behaviour.

## Pit boundary

Pit is a persistent helper for:
1. capture;
2. clarification;
3. progressive discovery.

Pit is not:
- root navigation;
- a chat tab;
- the only input method;
- a generic AI assistant;
- an AI mechanic by default;
- a source of unsolicited technical claims.

The application remains fully usable without Pit.

## Product principles

1. User-first, not vehicle-first.
2. Value before profile completion.
3. Remember first; classify second.
4. Raw user meaning is never discarded.
5. AI proposes; deterministic domain code decides.
6. One question at a time.
7. Unknown is a valid state.
8. Sparse UI must still look intentional.
9. Native Apple patterns are the default.
10. Pit may look alive without permission; Pit may interrupt only for measurable value.
11. The user can always inspect and correct stored data.
12. Do not build future intelligence before the product core is validated.

## Explicit non-goals for the first product slice

- vehicle diagnostics;
- health score;
- predictive failure detection;
- full fleet management;
- mandatory cloud account;
- generic chatbot;
- complete manufacturer database;
- VIN-first setup;
- custom dashboard builder;
- user-resizable tiles;
- CarPlay before investigation;
- AI-generated maintenance truth.

## Product-core success criteria

- first value without authentication;
- Car Board immediately renders a coherent car context;
- Notes, Service, and History are understandable without tutorial prose;
- Road communicates at least one meaningful next horizon when data exists;
- Settings is one tap away;
- Pit is one tap away;
- a thought can be captured with minimal friction;
- captured data has an understandable destination;
- stored data can be inspected and corrected;
- the app remains useful when AI is unavailable.

## Product-core failure criteria

- setup blocks Home;
- a vehicle form is mandatory;
- authentication is required before value;
- Pit is required for navigation;
- Car Board becomes empty navigation tiles;
- ordinary capture requires typing;
- users cannot understand where captured information went;
- Road is decorative rather than informative;
- Pit interrupts without visible value;
- manufacturer data becomes a prerequisite for usefulness.
