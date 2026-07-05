# Logging Decision

**Status:** Accepted direction\
**Decision:** use Apple's OSLog/Logger directly behind a tiny typed
event facade; no third-party logging framework in P0.

## Requirement

Developer logs are for local DEBUG diagnosis.

For TestFlight/product behavior use product analytics and
crash/performance diagnostics, not verbose application logs.

## Decision

Use:

``` text
OSLog.Logger
+
typed feature log events
+
DEBUG-only emission
```

Do not build: - logging backend abstraction; - remote log transport; -
log persistence/database; - log upload UI; - generic public logger
package; - swift-log adapter unless a real non-Apple/library consumer
appears.

## Why not swift-log now

SwiftLog is a mature unified logging API with pluggable `LogHandler`
backends.

PitStop is currently Apple-only and does not need backend portability.
Adding a backend-neutral logging layer would solve a hypothetical
requirement.

Revisit if a reusable remote Swift package needs consumer-controlled
logging.

## Why not Pulse now

Pulse is useful for local network logging/inspection. PitStop does not
currently have a network-heavy debug problem.

Revisit for a future remote API/RAG backend.

## API shape

Feature-owned event:

``` swift
enum MaintenanceLogEvent: Sendable {
    case snapshotRebuilt(
        reason: SnapshotRebuildReason,
        operationCount: Int,
        dueCount: Int
    )

    case operationExcluded(
        operation: MaintenanceOperationID,
        reason: ExclusionReason
    )
}
```

Usage:

``` swift
log(.snapshotRebuilt(
    reason: .odometerUpdated,
    operationCount: operations.count,
    dueCount: due.count
))
```

The call site contains: - no message string; - no category string; - no
privacy interpolation; - no arbitrary metadata dictionary.

## Implementation

A minimal `PitStopLogging` local SPM target may contain:

``` text
LogEvent protocol/internal encoding contract
FeatureLog<Event>
DEBUG compilation behavior
OSLog.Logger adapter
```

Target size is intentionally small.

If the implementation grows beyond a few focused files, stop and review
whether the abstraction is becoming a custom logging framework.

## DEBUG-only rule

In non-DEBUG application builds:

``` text
feature debug/info log facade → no-op
```

`fault`/crash diagnostics are not solved by this logger. They belong to
the selected crash diagnostics service or system diagnostics.

Do not assume TestFlight testers can provide useful local unified logs.

## Privacy by types

Prefer:

``` swift
case noteCreated(contextCount: CountBucket)
```

Impossible:

``` swift
case message(String)
```

Do not expose a public escape hatch:

``` swift
log("anything")
log(metadata: [String: Any])
```

## Performance

Logging calls must not construct expensive strings or serialize entities
before the DEBUG gate.

Add a micro/performance check only if measurement shows the facade in a
hot path.

## Acceptance criteria

-   no new production `print`;
-   no arbitrary string logging API;
-   DEBUG build emits OSLog records with subsystem/category;
-   non-DEBUG feature logging is a no-op;
-   raw notes/transcripts/VIN cannot be represented by standard events;
-   logging package has no remote/network dependency;
-   logging is not used as TestFlight analytics.

## Re-evaluation triggers

-   reusable library has non-Apple consumers;
-   a second logging backend is required;
-   remote diagnostic logging becomes a product requirement;
-   network debugging justifies Pulse.
