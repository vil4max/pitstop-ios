# Telemetry Contract

## Four distinct channels

Do not merge logging, product analytics, crash diagnostics, or AI runtime
observability.

### DEBUG diagnostics

Purpose: - engineering diagnosis; - stage/reason visibility; - local
development only.

Implementation direction:

``` text
OSLog.Logger
→ typed debug events
→ DEBUG-only typed facade
```

Source of truth: `22_LOGGING_DECISION.md`

Do not use product analytics as a debug log.

### Product behavior

Purpose: - aggregate product behavior; - research funnels; - bounded
evidence for `AQ-*` questions.

Implementation direction:

``` text
typed analytics events
→ provider-neutral analytics boundary
→ PostHog adapter candidate (pending ANL-001)
```

Source of truth for provider selection:
`21_ANALYTICS_SERVICE_DECISION.md`

Source of truth for event taxonomy: `07_ANALYTICS.md`

Source of truth for product questions: `29_ANALYTICS_QUESTIONS.md`

Do not describe Firebase Analytics as a telemetry channel.

Firebase Analytics is an evaluated alternative only. See
`21_ANALYTICS_SERVICE_DECISION.md`.

### Crash / stability diagnostics

Purpose: - crashes; - selected non-fatal invariants; - release
stability.

Current beta direction: Firebase Crashlytics.

Crash reporting is a separate decision from product analytics.

Do not use Crashlytics as a product database.

### AI runtime observability

Purpose: - model availability; - generation latency; - failure reason;
- interpreter version metadata; - evaluation traces.

This is not product analytics.

AI product analytics workflow source of truth:
`30_AI_PRODUCT_ANALYTICS.md`

PitStop P0 does not automatically enable a separate AI observability
product.

## Naming registry

Logging subsystem:

``` text
com.pitstop.app
```

Categories:

``` text
app.lifecycle
persistence
maintenance.engine
maintenance.planner
notes
history
odometer
ai.interpreter
widget
siri
sync
analytics
```

Analytics event names are defined only in `07_ANALYTICS.md`.

## Data classification

### Never remote-log by default

``` text
raw note
raw prompt
voice transcript
VIN
license plate
photo
OCR text
invoice text
dealer document
exact free-text feedback
```

AI-assisted analytics must not receive these by default. See
`30_AI_PRODUCT_ANALYTICS.md`.

### Allowed bounded telemetry

``` text
intent enum
context enum
status enum
source enum
boolean
count bucket
duration bucket
version string
error reason code
```

### Review required

``` text
exact odometer
vehicle make/model
exact amount
exact dates
user identifier
```

## Error reason codes

Errors should be typed/bounded.

Example interpreter reasons:

``` text
model_unavailable
generation_failed
unsupported_intent
validation_failed
ambiguous_numeric_value
missing_required_field
```

Planner reasons:

``` text
unknown_baseline
not_applicable
outside_grouping_window
recently_completed
policy_missing
```

## Version fields

Track: - app version; - schema version; - maintenance engine version; -
interpreter version; - maintenance knowledge pack version later.

## Telemetry change gate

Adding an event/parameter requires: - research question (`AQ-*` or
approved investigation); - expected decision it can influence; -
privacy classification; - cardinality review.

If no decision depends on it, do not collect it.

## Source-of-truth references

``` text
Analytics provider:
21_ANALYTICS_SERVICE_DECISION.md

Product analytics questions:
29_ANALYTICS_QUESTIONS.md

Event taxonomy:
07_ANALYTICS.md

AI-assisted analytics workflow:
30_AI_PRODUCT_ANALYTICS.md

Logging:
22_LOGGING_DECISION.md
```
