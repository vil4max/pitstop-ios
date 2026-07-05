# Product Analytics

## Decision

Use Firebase Analytics for the research beta.

Use Firebase Crashlytics for stability diagnostics.

Firebase is telemetry infrastructure only. SwiftData/iCloud remain the
product data direction.

Do not add Firestore merely because Firebase is present.

## Analytics objective

Answer product research questions, not collect everything.

Primary questions:

1.  Do users complete lightweight vehicle setup?
2.  Do they create real Notes/History facts?
3.  Do context views provide recall value?
4.  Does Tell PitStop reduce input friction?
5.  Do users trust/understand maintenance status?
6.  Does the planner's suggested service scope match real decisions?

## Privacy contract

Never send by default: - raw note text; - voice transcript; - prompt; -
VIN; - license plate; - exact service document text; - photo; - dealer
invoice content; - exact odometer value; - free-text error description.

Use enums, booleans, counts and buckets.

## Event naming

Lowercase snake_case.

Pattern:

``` text
noun_verb
```

Examples:

``` text
onboarding_completed
note_created
note_archived
note_context_opened
input_interpretation_completed
draft_saved
draft_cancelled
odometer_updated
maintenance_status_viewed
service_scope_viewed
service_plan_edited
history_event_created
```

Do not encode values into event names.

Bad:

``` text
created_car_wash_note
created_service_note
```

Use:

``` text
note_created
context=car_wash
```

## P0 event taxonomy

### onboarding_completed

Parameters:

``` text
input_mode = natural | explicit | seeded
vehicle_draft_edited = true | false
odometer_present = true | false
duration_bucket
```

### note_created

``` text
input_source = text | voice | explicit | siri
context_count_bucket
has_canonical_context
```

### note_context_opened

``` text
context = car_wash | service | shopping
active_note_count_bucket
```

### note_archived

``` text
source_context = all | car_wash | service | shopping
age_bucket
```

### input_interpretation_completed

``` text
intent
availability
result = draft | fallback | error | unsupported
latency_bucket
interpreter_version
```

### draft_saved

``` text
intent
edited = true | false
```

### draft_cancelled

``` text
intent
stage = preview | edit
```

### odometer_updated

``` text
source = explicit | natural | siri | document
anomaly_confirmation = none | accepted | corrected
```

No exact odometer.

### maintenance_status_viewed

``` text
overall_status
unknown_count_bucket
due_count_bucket
```

### service_scope_viewed

``` text
due_count_bucket
nearby_count_bucket
optional_count_bucket
note_count_bucket
```

### service_plan_edited

``` text
due_removed_count_bucket
nearby_removed_count_bucket
optional_added_count_bucket
optional_removed_count_bucket
```

This event is highly valuable for validating planner logic.

### history_event_created

``` text
kind
input_source
has_amount
has_document
```

## User properties

Keep minimal.

Potential:

``` text
beta_cohort
vehicle_setup_mode
```

Avoid make/model as a user property in the five-person beta unless a
specific research question requires it. With five users, rare
combinations can become identifying.

## Funnels

### Activation

``` text
app first open
→ onboarding completed
→ home viewed
→ first note/history/odometer fact
```

### Natural input

``` text
input started
→ interpretation completed
→ draft shown
→ draft saved
```

### Context memory

``` text
note created with context
→ context opened later
→ note archived/shared
```

### Service planning

``` text
scope viewed
→ plan edited
→ service history recorded
→ planned vs performed comparison
```

## Initial success thresholds

Natural input: - supported intent draft rate ≥ 90% on controlled
evaluation; - beta save rate ≥ 70%; - cancel rate investigated if
\>20%; - edited drafts are not automatically considered failure;
field-level edit analysis is a later local research tool.

Context views: - at least 3/5 testers reopen a context with existing
notes.

Planner: - due items removed from plan must be reviewed qualitatively; -
if \>30% of due-nearby suggestions are removed, grouping rules require
review.

## Analytics validation

Before every TestFlight release: - enable Analytics DebugView on a
development device; - execute the telemetry smoke checklist; - verify
parameter names; - verify no private raw text; - verify event
cardinality remains bounded.

## Free-tier boundary

The beta should remain on no-cost telemetry products. Analytics and
Crashlytics are selected specifically because the current Firebase
documentation lists Analytics as no-charge and Crashlytics as no-cost.
If a later feature requires paid Firebase/Google Cloud infrastructure,
that is a separate ADR and budget decision.
