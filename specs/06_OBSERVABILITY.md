# Observability

## Objective

Logs must explain the deterministic and AI pipelines without leaking
private user content.

Use Apple unified logging through `Logger`.

Crash diagnostics use Firebase Crashlytics in beta.

Performance investigation may use signposts and MetricKit where useful.

## Logging architecture

Create a thin app-owned logging facade.

Conceptual categories:

``` text
app.lifecycle
persistence
maintenance.engine
maintenance.planner
notes
history
odometer
ai.interpreter
ai.evaluation
widget
siri
sync
analytics
```

Do not create a global `print()` culture.

Production code: - no `print`; - no raw dump of SwiftData entities; - no
raw prompt/transcript logging; - no VIN logging; - no service-document
OCR text logging.

## Log levels

### debug

Detailed development flow. May be compiled/visible for debugging but
still must respect privacy.

Example:

``` text
maintenance progress calculated
operation=engineOil
policyType=distance
status=approaching
```

### info

Important successful lifecycle boundary.

``` text
maintenance snapshot rebuilt
operations=8
unknown=2
due=1
```

### notice

Meaningful product/system state change.

``` text
effective maintenance policy changed
operation=dsgService
source=user
```

### error

Recoverable failure requiring diagnosis.

``` text
input interpretation failed
availability=available
errorType=generation
```

### fault

Invariant breach or data integrity risk.

``` text
completion references unknown operation ID
```

## Correlation IDs

Important multi-stage pipelines receive an ephemeral correlation ID.

Example:

``` text
Tell PitStop
correlationID=...

interpretation started
draft produced
validation completed
confirmation saved
snapshot rebuilt
```

Do not use stable user identifiers as correlation IDs.

## Structured fields

Prefer enums/counts/buckets.

Good:

``` text
intent=odometer
validation=success
latencyBucket=500_1000ms
draftEdited=true
```

Bad:

``` text
input="Сегодня мойка 500 гривен..."
```

## Maintenance engine logging contract

On snapshot rebuild:

``` text
reason
operationCount
unknownCount
approachingCount
dueCount
duration
```

For per-operation debug logging:

``` text
operationID
policyType
baselineState
status
```

Avoid logging exact sensitive service history unless needed. Mileage is
not sent to analytics by default; local unified logging should use
privacy-aware interpolation.

## Service planner logging contract

``` text
anchorOperationID?
dueCount
nearbyCount
optionalCount
notesCount
resultOperationCount
```

When an operation is excluded:

``` text
operationID
reasonCode
```

Reason codes:

``` text
notDue
outsideGroupingWindow
recentlyCompleted
unknownBaseline
notApplicable
```

## AI interpreter logging contract

``` text
correlationID
interpreterVersion
availability
intent
latencyBucket
validationResult
fallbackUsed
```

Never log raw natural input in production.

## Crashlytics

Use Crashlytics for: - crashes; - selected non-fatal invariant
failures; - custom keys with bounded enums/version information; -
breadcrumb context from safe analytics events.

Recommended custom keys:

``` text
app_schema_version
maintenance_engine_version
interpreter_version
current_screen
last_domain_action
```

Do not attach: - VIN; - raw note; - transcript; - OCR text; - dealer
invoice; - full odometer history; - user name/email as custom user ID.

## Signposts

Add signposts only to pipelines where duration matters:

``` text
maintenance snapshot rebuild
service-plan composition
Foundation Models interpretation
document OCR/extraction
SwiftData migration
```

Success: - Instruments can show start/end duration for a pipeline.

Failure: - every method has a signpost; - signpost names include user
content.

## Observability acceptance gate

For every new domain pipeline ask:

> If this fails for one TestFlight friend, can I identify the stage and
> reason without asking them to reproduce it with Xcode attached?

If no, observability is incomplete.
