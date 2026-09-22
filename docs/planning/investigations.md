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

Evidence (external reference, unvalidated): mewmori.com's pet-companion
mechanic and OpenAI Codex's mascot use, raised as a "Pit as pet" framing to
weigh against the existing eyes-only hypothesis in `../requirements/product-design.md`.

## Road investigations

Decided 2026-09-20 in [`../decisions/0008-road-projection-rules.md`](../decisions/0008-road-projection-rules.md); the questions below are kept as the record of what was asked.

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

### ROAD-EST-001 Mileage-rate estimate for distance milestones

Question: Can Road show a labelled date range for a distance milestone,
derived from reading history, without breaking core C2 and REQ-ROAD-007?

Record: [`investigations/road-est-001-mileage-rate-estimate.md`](investigations/road-est-001-mileage-rate-estimate.md)
(investigated 2026-09-22; approved by the owner on 2026-09-22). Answered: an
annotation-only estimate that never places or orders a milestone, shipped as
ROAD-EST-002 with the REQ-ROAD-007 wording change and REQ-ROAD-022/023
([ADR 0034](../decisions/0034-mileage-rate-estimate.md)).

## Capture investigations

### INV-CAP-001 Semantic false classification

Question: What proposal error rate is acceptable per mutation class?

Separate low-risk Note classification from maintenance completion or vehicle facts.

### INV-CAP-002 Confirmation frequency

Question: Which mutations can be accepted without confirmation?

Goal: minimise friction without unsafe mutation.

### INV-CAP-003 Siri/widget capture latency

Question: Can system capture feel materially faster than opening the app?

Siri part scoped by SYS-001: measure cold background launch to reply time on
a device in SYS-006.
Widget part scoped by SYS-004
([`investigations/sys-004-widgets.md`](investigations/sys-004-widgets.md)):
widgets and controls open the app on the Pit sheet; they cannot capture text
themselves.

### INV-CAP-004 Microphone activation constraints

Investigate widget/deep-link-to-capture platform constraints.

Deep-link part answered by SYS-004
([`investigations/sys-004-widgets.md`](investigations/sys-004-widgets.md));
microphone start stays open because Pit has no voice capture yet.

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

Investigated 2026-09-21 in MNT-INT-001
([`investigations/mnt-int-001-maintenance-intelligence.md`](investigations/mnt-int-001-maintenance-intelligence.md)):
no app-supplied manufacturer data for now; owner decision pending.

### INV-VEH-003 Progressive vehicle discovery

Question: Which vehicle facts unlock immediate product value?

Do not optimise for profile completeness.

### INV-VEH-004 Regional priors

Question: Can locale/App Store region safely improve choice ordering?

Region may reorder options. It must not become vehicle truth.

## Maintenance investigations

### INV-MNT-001 Procedure composition

Can official sources reliably identify required components of procedures?

Partly addressed by MNT-INT-001: procedure composition shares the source,
licence, and verification problem of INV-VEH-002; a fictional fixture test is
proposed (MNT-INT-002).

### INV-MNT-002 Service grouping

What grouping window matches real owner behaviour?

### INV-MNT-003 User interval overrides

Validate how users express simple anchor philosophies such as 5/7.5/10/15 thousand km.

### MNT-INT-001 Maintenance intelligence (Phase 7)

Question: Which manufacturer data, presets, and richer Road milestones are
viable after core product validation, and under which gates?

Record: [`investigations/mnt-int-001-maintenance-intelligence.md`](investigations/mnt-int-001-maintenance-intelligence.md)
(investigated 2026-09-21; owner decisions pending). The full record lives in
its own file because it cites external sources and proposes follow-up tasks.

### MNT-VR-001 Vehicle-reported remaining value

Question: How should an owner-entered dashboard countdown ("service in
3,200 km / 45 days") act as a maintenance rule next to owner intervals and
completions?

Record: [`investigations/mnt-vr-001-vehicle-reported-remaining.md`](investigations/mnt-vr-001-vehicle-reported-remaining.md)
(investigated 2026-09-22; owner decisions pending). Recommends a separate
report record superseded by the next completion, earliest anchor wins, gated
on owner precedence choice and evidence of demand.

## System investigations

### INV-SYS-001 App Intents phrase UX

Partly addressed by SYS-001
([`investigations/sys-001-app-intents.md`](investigations/sys-001-app-intents.md)):
phrases need the app name, cannot carry free text, and are localized through
an `AppShortcuts` String Catalog; Russian and Ukrainian phrase recognition
needs a device check (SYS-006).

### SYS-001 App Intent investigation

Question: Under which platform constraints can `RememberInPitStopIntent`
feed the one capture pipeline, and how are confirmation, cancellation, and
time limits handled?

Record: [`investigations/sys-001-app-intents.md`](investigations/sys-001-app-intents.md)
(investigated 2026-09-21; owner decisions pending). The full record lives in
its own file because it cites Apple documentation and specifies SYS-002.

### SYS-004 Widget investigation

Question: Which widget and control surfaces can open the Pit capture surface
on iOS 27, how does the intent reach the widget extension, and does the first
slice need shared data?

Record: [`investigations/sys-004-widgets.md`](investigations/sys-004-widgets.md)
(investigated 2026-09-21; owner decisions pending). Recommends a data-free
SYS-005: an "Open Pit" control and a static widget, no App Group.

### INV-SYS-002 Action Button applicability

Addressed by SYS-004
([`investigations/sys-004-widgets.md`](investigations/sys-004-widgets.md)):
the Action button runs an App Shortcut (both ADR 0024 shortcuts qualify) or a
control; an "Open Pit" control adds one more assignable entry.

### INV-SYS-003 Lock Screen / Control Center applicability

Addressed by SYS-004
([`investigations/sys-004-widgets.md`](investigations/sys-004-widgets.md)):
a control whose action is an `OpenIntent` opens the app from Control Center
and the Lock Screen; the intent must be compiled into the app and the widget
extension.

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
