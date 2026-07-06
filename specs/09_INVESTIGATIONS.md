# Investigation Register

An investigation is complete only when it ends with:

```text
Question
Evidence
Options
Decision
Why
Rejected alternatives
Implementation impact
Follow-up tasks
```

## Product-core investigations

### INV-PROD-001 Repeated value after week one

Question: Does contextual car memory create repeated value after initial setup curiosity?

Evidence:
- dogfood;
- small beta;
- Remember frequency;
- return sessions;
- interviews.

Failure signal: product becomes a one-time vehicle setup exercise.

### INV-PROD-002 Remember habit

Question: Is `Remember` frequent and useful enough to become a recurring behaviour?

Measure:
- time to first memory;
- memories per active week;
- capture source;
- correction rate;
- retrieval/open rate.

### INV-PROD-003 Car Board comprehension

Question: Is Car Board obvious without tabs?

Test:
- first-use task comprehension;
- feature discovery;
- Settings discovery;
- Pit discovery.

Failure: users hunt for navigation or interpret tiles as static widgets.

### INV-PROD-004 Notes differentiation

Question: Are car-context Notes meaningfully different from generic Notes/Reminders?

Failure: users prefer the system Notes app for the same job.

### INV-PROD-005 Pit value vs mascot noise

Question: Does Pit improve capture/discovery without becoming distracting?

Evaluate:
- Pit use;
- dismissals;
- question answer rate;
- motion sentiment;
- ability to use app without Pit.

## Road investigations

### INV-ROAD-001 Horizon and spacing

Question: What initial horizon makes Road useful with sparse and dense milestone sets?

Compare:
- fixed six months;
- nearest-N milestones;
- adaptive bounded horizon.

### INV-ROAD-002 Mixed time/mileage representation

Question: How should date and mileage milestones coexist without fake conversion?

Decision must define stale/unknown mileage behaviour.

### INV-ROAD-003 Milestone clustering

Question: When should nearby milestones visually cluster?

Do not assume Service Planner grouping equals Road grouping.

### INV-ROAD-004 Return to current position

Question: What native-feeling mechanism returns a scrolled Road to default/current position?

No custom gesture without evidence.

## Capture investigations

### INV-CAP-001 Semantic false classification

Question: What proposal error rate is acceptable per mutation class?

Separate low-risk Note classification from maintenance completion or vehicle facts.

### INV-CAP-002 Confirmation frequency

Question: Which mutations can be accepted without confirmation?

Goal: minimise friction without unsafe mutation.

### INV-CAP-003 Siri/widget capture latency

Question: Can system capture feel materially faster than opening the app?

### INV-CAP-004 Microphone activation constraints

Investigate widget/deep-link-to-capture platform constraints.

### INV-CAP-005 Foundation Models language quality

Evaluate real Russian input, short fragments, automotive slang, mixed Russian/English vehicle terms, and ambiguity.

Success:
- typed proposals are useful;
- unsupported meaning safely falls back to raw preservation.

## Pit investigations

### INV-PIT-001 Idle motion frequency

Question: How often can Pit visibly move before becoming noise?

A normal session may contain no idle animation.

### INV-PIT-002 Attention value policy

Question: What measurable threshold justifies a Pit question?

Every candidate question must document value unlocked.

### INV-PIT-003 Interruption cooldown

Determine dismissal/defer/repeat policy.

### INV-PIT-004 Accessibility

Validate Reduce Motion and VoiceOver behaviour.

## Vehicle-data investigations

### INV-VEH-001 Vehicle hero image

Decision path:
1. neutral deliberate placeholder;
2. optional PhotosPicker image;
3. exact model imagery only after licensing/API investigation.

Failure: wrong model/generation shown as the user's car.

### INV-VEH-002 Official maintenance data

Can PitStop legally and reliably curate official manufacturer recommendations?

Investigate:
- source availability;
- redistribution rights;
- market specificity;
- model-year/powertrain applicability;
- source revision;
- correction workflow.

### INV-VEH-003 Progressive vehicle discovery

Question: Which vehicle facts unlock immediate product value?

Do not optimise for profile completeness.

### INV-VEH-004 Regional priors

Question: Can locale/App Store region safely improve choice ordering?

Region may reorder options. It must not become vehicle truth.

## Maintenance investigations

### INV-MNT-001 Procedure composition

Can official sources reliably identify required components of procedures?

### INV-MNT-002 Service grouping

What grouping window matches real owner behaviour?

### INV-MNT-003 User interval overrides

Validate how users express simple anchor philosophies such as 5/7.5/10/15 thousand km.

## System investigations

### INV-SYS-001 App Intents phrase UX

### INV-SYS-002 Action Button applicability

### INV-SYS-003 Lock Screen / Control Center applicability

### INV-SYS-004 Spotlight applicability

### INV-SYS-005 CarPlay

Do not commit to CarPlay before platform and product-value validation.

## Architecture investigations

### INV-ARCH-001 Capture boundary

Validate that all sources can use one `CaptureInput` and command pipeline.

### INV-ARCH-002 Cross-feature dependency growth

Car Board aggregates projections. Prevent feature modules from importing each other arbitrarily.

### INV-ARCH-003 Existing data migration

Inventory and map seeded/hard-coded note-like records before replacement.

### INV-ARCH-004 Modularity pressure

Use narrow contracts. Do not introduce protocols without a substitution/testing/boundary reason.
