# Analytics Service Decision

**Status:** Candidate selected for beta\
**Selected candidate:** PostHog\
**Decision type:** reversible infrastructure choice

## Product requirement

PitStop needs product analytics for a five-car research beta and later
growth.

Required: - custom events and properties; - funnels; -
retention/cohorts; - event-level inspection during beta; - iOS Swift
SDK/SPM; - generous free tier; - feature flags/experiments useful
later; - no raw note/transcript/VIN telemetry; - provider hidden behind
app-owned typed feature analytics APIs.

Not required for P0: - web marketing analytics; - data warehouse; -
session replay; - autocapture; - a generic analytics framework for
third-party apps.

## Candidates

  ----------------------------------------------------------------------------------------------
  Criterion           PostHog              Firebase Analytics TelemetryDeck   Aptabase
  ------------------- -------------------- ------------------ --------------- ------------------
  Product             strong               strong             focused mobile  simple analytics
  analytics/funnels                                           analytics       

  Retention/cohorts   strong               strong             available       simpler
                                                              product         
                                                              analytics       
                                                              orientation     

  iOS SDK             yes                  yes                Swift-first     Swift SDK

  SPM                 yes                  yes                yes             yes

  Free entry          1M product analytics Analytics          free start      free/open-source
                      events/month         no-charge          advertised      positioning
                      advertised                                              

  Feature flags       yes                  via Firebase       not core        not core
                                           ecosystem/Remote   selection       
                                           Config             reason          

  Experiments         yes                  Firebase A/B       not core        not core
                                           ecosystem                          

  Session replay iOS  yes                  no                 no selection    no
                                           Analytics-native   reason          
                                           replay                             

  Open                PostHog platform has no                 service SDK     platform
  source/self-host    OSS roots; cloud                        visible         positioned open
  option              selected for beta                                       source

  Privacy positioning configurable; our    Google/Firebase    privacy-first   privacy-first
                      event policy         disclosure review                  
                      required             required                           

  Product-lab breadth very high            high mobile        intentionally   intentionally
                                           ecosystem breadth  focused         simple

  Vendor complexity   medium/high          medium             low             low

  Risk of             high if              medium             lower           lower
  over-collection     autocapture/replay                                      
                      enabled                                                 
  ----------------------------------------------------------------------------------------------

## Why PostHog

PostHog's current official pricing advertises the first 1,000,000
product analytics events per month free. Its iOS SDK supports event
capture, feature flags, experiments and iOS session replay.

For PitStop this creates one useful learning surface:

``` text
analytics now
→ feature flags later
→ controlled beta experiments later
```

The decision is **not** "PostHog has more features, therefore use all
features."

P0 configuration:

``` text
custom typed events       ON
autocapture               OFF
screen auto-capture       OFF unless explicitly evaluated
session replay            OFF
identify with PII         OFF
feature flags             OFF until first flag use case
surveys                    OFF
```

## Why not Firebase Analytics as primary

Firebase Analytics is available at no charge and integrates naturally
with Crashlytics.

It remains a strong candidate.

PostHog wins the beta decision because PitStop's current question is
product behavior: funnels, retention, event exploration and later
experiments. The broader product analytics workflow is a closer fit to
the laboratory.

Crash reporting is a separate decision. Do not keep Firebase Analytics
merely to justify Crashlytics.

## Why not TelemetryDeck

TelemetryDeck is a strong Swift/mobile/privacy-first option and its
Swift SDK is deliberately small.

It is the preferred fallback if PostHog feels too broad or privacy
review becomes disproportionate.

It loses P0 selection because PitStop explicitly wants product
experimentation as a learning track, not only minimal app analytics.

## Why not Aptabase

Aptabase is open-source, privacy-first and simple.

It is attractive for a smaller analytics surface. PitStop currently
benefits from deeper product-analysis tooling and future experiments.

## Architecture boundary

Feature code never imports PostHog.

Example:

``` swift
public protocol NotesAnalytics: Sendable {
    func track(_ event: NotesAnalyticsEvent)
}

public enum NotesAnalyticsEvent: Sendable {
    case noteCreated(
        source: NoteInputSource,
        contextCount: CountBucket
    )
    case contextOpened(
        context: NoteContext,
        activeCount: CountBucket
    )
}
```

Feature usage:

``` swift
analytics.track(.contextOpened(
    context: .carWash,
    activeCount: .threeToFive
))
```

Infrastructure:

``` text
NotesFeature
    ↓ NotesAnalytics
LiveNotesAnalytics
    ↓ AnalyticsClient
PostHogAnalyticsClient
    ↓ PostHog SDK
```

`PostHogAnalyticsClient` is an example concrete adapter type name, not a
mandatory module name.

No event name string exists in feature code.

## Module rule

Each feature owns: - analytics protocol; - typed feature event; -
semantic parameters.

`Analytics` (provider-neutral boundary) owns: - provider-neutral encoded
event; - `AnalyticsClient`; - NoOp client; - Recording client for tests;
composition/multiplexing only if a second real provider appears.

The PostHog adapter owns: - PostHog import; - SDK initialization; - event
encoding/send boundary.

Start with the smallest local implementation. Extract dedicated packages
only when dependency boundaries require them.

Do not create `AppAnalytics: NotesAnalytics, MaintenanceAnalytics, ...`.

## Analytics acceptance criteria

-   concrete analytics provider SDK appears in one adapter boundary only;
-   Domain modules do not import analytics SDKs.
-   Feature event APIs contain no arbitrary strings/dictionaries.
-   Autocapture and replay are off.
-   No prohibited raw content reaches PostHog.
-   Debug/test builds can use RecordingAnalytics.
-   One beta funnel is reproducible from events.
-   Provider can be replaced without changing feature behavior.

Failure: feature code imports or calls a concrete analytics provider
directly.

## Re-evaluation triggers

Review PostHog if: - SDK/app-size or startup impact is material; -
privacy disclosure burden conflicts with product direction; - five-user
beta needs only simple counters; - event debugging is worse than
expected; - cost trajectory exceeds the free tier assumptions; - a
second analytics provider is genuinely required.

## P0 spike

`ANL-001 — PostHog vertical slice`

Purpose: validate analytics boundary, PostHog iOS integration, typed
event mapping, and privacy/configuration assumptions.

This does **not** mandate creating separate Analytics and PostHog adapter
SPM packages. Start with the smallest local boundary justified by the
current repository.

Implement only:

``` text
car_context_first_enriched
note_created
note_context_opened
```

Measure: - binary/app launch impact; - event delivery/debug
ergonomics; - dashboard/funnel setup time; - privacy manifest/App
Privacy implications; - SDK behavior offline.

Decision after spike:

``` text
ADOPT
ADOPT WITH BOUNDARY
FALL BACK TO TELEMETRYDECK
```
