# Product Charter

For design rationale (why), see [`41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`](41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md).  
For mandatory idea validation before new features, see [`42_PRODUCT_REVIEW.md`](42_PRODUCT_REVIEW.md).  
For freeze / resume status, see [`../PROJECT_STATUS.md`](../PROJECT_STATUS.md).

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

## Product loop and feature responsibilities

The core loop is **save a thought → find and use it → record what actually
happened → understand what matters next**. Not every thought becomes a task,
service event, or reminder. A useful Note may remain a Note.

The following descriptions define intended behaviour, not shipped capability.
Current implementation is recorded in [`39_DOMAIN_INVENTORY.md`](39_DOMAIN_INVENTORY.md).

| Capability / surface | User's question or trigger | Minimum useful result | Boundary and dependencies |
|---|---|---|---|
| Remember | "I need to save this before I forget." | Preserve the input, show where it was saved, and let the user inspect it later. | A capability, not a screen or model. Raw saving needs no AI; interpretation may propose structure. Both use the capture contract in `34`. |
| Notes | "What did I want to remember or ask about?" | Read, correct, and archive saved thoughts; find them again through an understandable list or supported context. | Original wording is authoritative. A context is optional metadata, not a required taxonomy. Archiving is not proof that work was performed. Domain owner: `02`. |
| History | "What actually happened, and when?" | Inspect recorded vehicle events with their known date, mileage, performed work, and optional cost. | Contains recorded facts, not intentions or unconfirmed proposals. Service completion has its own confirmation rules. Domain owner: `02`. |
| Service | "What is approaching, what should I plan, and what was done?" | Explain known maintenance status, help plan a visit, and record confirmed operations. | Depends on effective policies and completion facts. Unknown stays unknown; partial service resets only completed operations. Behaviour owner: `03`. |
| Road | "What meaningful event is ahead?" | Show the nearest relevant milestone or an honest no-known-milestones state. | A projection of known plans and deterministic maintenance state, not another planner, history database, or map. Behaviour owner: `32`. |
| Car Board | "What matters about my car right now?" | Show useful summaries and clear entrances to the owned surfaces. | Displays their data; does not create a second source of truth. A tile alone is not a complete feature. Screen owner: `31`. |
| Car context | "Which car is this, and which facts are known?" | Start with one provisional car and allow progressive correction/enrichment. | No profile gate. A display placeholder is not a mileage reading or a verified vehicle fact. Domain owner: `02`. |
| Pit | "Help me capture this or clarify one thing." | Open capture, present its outcome, or ask one useful question. | Optional interaction helper, not navigation, storage, a generic chat, or the AI model. Behaviour owner: `33`. |
| Settings | "Where can I change app preferences?" | Reach the owned settings surface in one tap. | A stable utility action, separate from car facts and primary navigation. Utility owner: `35`. |

### Example journeys

- **Before a car wash:** save "Ask about the stain on the rear seat"; reopen
  the saved Note later; correct or archive it. AI failure must not hide or lose it.
- **Looking back:** open History to check a recorded wiper replacement. If its
  date or mileage is missing, show that uncertainty rather than inventing it.
- **After a service visit:** confirm only the operations actually performed;
  record the visit in History; recalculate only the affected cycles in Service
  and the eligible milestones in Road. Unperformed work remains unchanged.

These journeys are acceptance examples, not automatic context-detection,
notification, diagnostic, or new system-integration requirements.

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
- ordinary structured facts require free-text entry when simple controls would suffice;
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
- saved notes remain findable without AI or automatic location detection;
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
mileage unknown
vehicle details unknown
```

This is a provisional product context, not a factual claim that the user bought a new vehicle.

Until a valid odometer reading exists, omit the numeric mileage or show an
explicit unknown label. Zero is a valid reading only when actually supplied;
it is not a substitute for missing data. The current scaffold's `0 km` is an
implementation gap, not the intended first-launch behaviour.

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
- a saved thought survives relaunch and can be found and used later;
- stored data can be inspected and corrected;
- the app remains useful when AI is unavailable.

## Product-core failure criteria

- setup blocks Home;
- a vehicle form is mandatory;
- authentication is required before value;
- Pit is required for navigation;
- Car Board becomes empty navigation tiles;
- structured capture imposes unnecessary typing or a mandatory voice interaction;
- users cannot understand where captured information went;
- Road is decorative rather than informative;
- Pit interrupts without visible value;
- manufacturer data becomes a prerequisite for usefulness.
