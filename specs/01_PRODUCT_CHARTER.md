# Product Charter

## Product statement

> PitStop is a smart memory for your car.

PitStop remembers: - what currently needs attention; - what the owner
does not want to forget; - what happened to the vehicle.

The user should not manage a maintenance database.

## Primary jobs to be done

### One-glance status

> When I look at PitStop, I want to understand in one glance whether
> maintenance needs my attention.

Success: - the answer is understandable in under two seconds; - the app
does not claim vehicle health or diagnostics; - the most important
maintenance state is deterministic.

Failure: - user must inspect a list to understand urgency; - red is used
for ordinary reminders; - AI invents a severity.

### Contextual memory

> When I arrive at a car wash or service center, I want to immediately
> see everything I wanted to remember there.

Success: - active notes for a canonical context are reachable in one
obvious action; - notes preserve original user wording; - context
metadata can be rebuilt.

Failure: - user must manually maintain tags; - AI rewriting replaces raw
text; - an interpretation failure loses a note.

### Frictionless capture

> When I remember something about the car, I want to tell PitStop
> naturally instead of selecting a form type.

Success: - text input produces a structured draft; - user confirms
meaningful mutations; - unsupported input can safely remain a raw note.

Failure: - LLM writes directly to SwiftData; - model availability blocks
core use; - ambiguous facts are silently guessed.

### Maintenance planning

> When several required maintenance operations converge, I want PitStop
> to compose one practical service plan.

Success: - each maintenance operation retains an independent
lifecycle; - nearby due operations are grouped into one practical
visit; - required procedure components, due work, nearby due work,
optional consumables and service notes are distinguished; - only
confirmed performed operations reset cycles.

Failure: - completing a visit marks every planned task done; - optional
cabin filter replacement becomes a mandatory due item without a rule; -
skipping DSG silently moves its anchor.

## Product boundaries

PitStop is not: - an OBD diagnostic product; - a vehicle-health
oracle; - a general expense tracker; - a service-center CRM; - an AI
chat product; - a multi-car fleet manager in the current beta.

## Product principles

1.  The app remembers; the user should not manage a database.
2.  Raw user facts are source of truth. AI metadata is derived.
3.  Swift decides maintenance truth and severity.
4.  AI interprets natural input and selects relevance; it does not
    calculate service truth.
5.  Natural input first, structured confirmation second.
6.  Never claim vehicle health without diagnostic evidence.
7.  One glance answers whether maintenance needs attention.
8.  A note must be easier to create than a reminder form.
9.  Context helps recall notes where they are useful.
10. History records car life; expenses are attributes of events.
11. Manufacturer guidance, vehicle-reported data and user policy are
    separate sources.
12. Maintenance policy is configurable per maintenance operation.
13. Service visits do not own maintenance schedules.
14. Independent maintenance cycles may be composed into one practical
    service plan.
15. A required procedure component is not the same as an optional
    recommendation.
16. A planned operation is not a completed operation.
17. CarPlay and motion are signals, not odometer truth.
18. A wrong vehicle image is worse than a deliberate neutral
    placeholder.
19. Every AI feature needs a safe non-AI path.
20. One-car beta is a research boundary, not permanent architecture.
21. If PitStop cannot confidently match an official schedule, it says so
    rather than guessing.
22. Product telemetry must not collect raw notes, voice transcripts, VIN
    or service-document text by default.

## North-star research question

After 30 days of real use:

> Did PitStop prevent the owner from forgetting something or reduce the
> effort of planning/recording vehicle maintenance?

If five beta users do not experience this value, adding more AI is not
success.

## Beta success criteria

Product beta is successful if: - at least 4/5 testers complete vehicle
setup; - at least 3/5 create three or more real notes or history
events; - at least 3/5 return to a context view or maintenance status
without being prompted by the developer; - natural input draft save rate
is at least 70% for supported intents; - edit-before-save rate is
measured and explainable; - no known data-loss bug remains open; - no
maintenance cycle resets from unconfirmed work; - users can explain the
home status without developer instruction.

Product beta is unsuccessful or requires redesign if: - most usage is
developer-driven; - users treat PitStop as a static checklist only; -
context views are not used; - natural input requires repeated
corrections; - maintenance status cannot be trusted; - the product
requires a long onboarding before first value.
