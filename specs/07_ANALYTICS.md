# Product Analytics

**Status:** `P0` event taxonomy\
**Owns:** event semantics, bounded properties, funnels derived from product questions\
**Does not own:** analytics provider selection

Provider source of truth: `21_ANALYTICS_SERVICE_DECISION.md`

Product question source of truth: `29_ANALYTICS_QUESTIONS.md`

AI-assisted analytics workflow source of truth: `30_AI_PRODUCT_ANALYTICS.md`

## Decision

PostHog is the **beta analytics candidate**, pending `ANL-001` vertical-slice
validation.

Use Firebase Crashlytics for stability diagnostics in beta.

Firebase Analytics is an **evaluated alternative**, not the current primary
product analytics provider. See `21_ANALYTICS_SERVICE_DECISION.md`.

SwiftData/iCloud remain the product data direction.

Do not add Firestore merely because Firebase crash tooling is present.

## Core rule

> Analytics starts with an explicit product question. Events exist to
> answer a product question, satisfy a release/diagnostic requirement,
> or support an approved investigation.

Do not preserve an event only because it may be useful later.

## Analytics objective

Answer registered product research questions, not collect everything.

Primary questions are defined in `29_ANALYTICS_QUESTIONS.md` as `AQ-*`
entries.

## Privacy contract

Never send by default: - raw note text; - voice transcript; - prompt; -
VIN; - license plate; - exact service document text; - photo; - dealer
invoice content; - exact odometer value; - free-text error description.

Use enums, booleans, counts and buckets.

AI-assisted analytics inherits the same denylist. See
`14_TELEMETRY_CONTRACT.md` and `30_AI_PRODUCT_ANALYTICS.md`.

## Event naming

Lowercase snake_case.

Pattern:

``` text
noun_verb
```

Examples:

``` text
car_context_first_enriched
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

## P0 event ownership

| Event | Product question / requirement | Status |
| --- | --- | --- |
| `car_context_first_enriched` | `AQ-002` lightweight vehicle setup | `P0` |
| `note_created` | `AQ-001`, `AQ-003` | `P0` |
| `note_context_opened` | `AQ-001` contextual recall value | `P0` |
| `note_archived` | `AQ-001` funnel support | `P0` |
| `input_interpretation_completed` | `AQ-004` Remember friction | `P0` |
| `draft_saved` | `AQ-004` | `P0` |
| `draft_cancelled` | `AQ-004` | `P0` |
| `odometer_updated` | `AQ-002`; release diagnostic for vehicle facts | `P0` |
| `maintenance_status_viewed` | `AQ-005` maintenance status trust | `P0` |
| `service_scope_viewed` | `AQ-006` planner alignment | `P0` |
| `service_plan_edited` | `AQ-006` | `P0` |
| `history_event_created` | `AQ-003` real Notes/History facts | `P0` |

Thresholds and decision rules live in `29_ANALYTICS_QUESTIONS.md`.

## P0 event taxonomy

### car_context_first_enriched

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

Funnels must map to an `AQ-*` question or an approved investigation.

### Activation — `AQ-002`, `AQ-003`

``` text
app first open
→ onboarding completed
→ home viewed
→ first note/history/odometer fact
```

### Natural input — `AQ-004`

``` text
input started
→ interpretation completed
→ draft shown
→ draft saved
```

### Context memory — `AQ-001`

``` text
note created with context
→ context opened later
→ note archived/shared
```

### Service planning — `AQ-006`

``` text
scope viewed
→ plan edited
→ service history recorded
→ planned vs performed comparison
```

## Research thresholds

All thresholds are provisional research thresholds, not KPI benchmarks.

Authoritative definitions: `29_ANALYTICS_QUESTIONS.md`.

Do not duplicate threshold values here.

## Analytics validation

Before every TestFlight release: - run the provider smoke checklist for
the selected analytics adapter (`ANL-001` output applies); - execute the
telemetry smoke checklist; - verify parameter names; - verify no private
raw text; - verify event cardinality remains bounded.

## Free-tier boundary

The beta should remain on no-cost or beta-tier telemetry products where
possible.

Analytics provider cost and adoption are decided in
`21_ANALYTICS_SERVICE_DECISION.md`.

Crashlytics remains a separate crash-diagnostics decision.

If a later feature requires paid infrastructure, that is a separate ADR
and budget decision.
