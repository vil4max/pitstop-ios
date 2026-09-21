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

Source of truth: `../decisions/0003-logging.md`

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
`../decisions/0002-analytics-service.md`

Source of truth for event taxonomy: `analytics.md`

Source of truth for product questions: `analytics-questions.md`

Boundary implementation, consent default (off until explicit opt-in), and
wired events: `../decisions/0021-analytics-boundary.md`. Proposed events for
shipped features are listed in `analytics.md` as `REVIEW` and are not
collected.

Do not describe Firebase Analytics as a telemetry channel.

Firebase Analytics is an evaluated alternative only. See
`../decisions/0002-analytics-service.md`.

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
`ai-product-analytics.md`

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
app.persistence
capture.pipeline
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

Analytics event names are defined only in `analytics.md`.

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
`ai-product-analytics.md`.

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
../decisions/0002-analytics-service.md

Product analytics questions:
analytics-questions.md

Event taxonomy:
analytics.md

AI-assisted analytics workflow:
ai-product-analytics.md

Logging:
../decisions/0003-logging.md
```
