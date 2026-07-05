# Telemetry Contract

## Three channels

### Unified logging

Purpose: - engineering diagnosis; - stage/reason visibility; - local
system integration.

### Crashlytics

Purpose: - crashes; - selected non-fatal invariants; - release
stability.

### Firebase Analytics

Purpose: - aggregate product behavior and research funnels.

Do not use Analytics as a debug log.

Do not use Crashlytics as a product database.

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

Adding an event/parameter requires: - research question; - expected
decision it can influence; - privacy classification; - cardinality
review.

If no decision depends on it, do not collect it.
