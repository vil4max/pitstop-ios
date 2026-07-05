# Learning Laboratory

## Purpose

PitStop is a production-oriented application and a deliberate learning
system for modern Apple and AI technologies.

Learning must produce: - a working feature or rejected experiment; -
tests/evaluations; - an ADR or investigation note; - a concise
explanation in the repository.

Watching a WWDC session is not completion.

## Technology study protocol

For every new technology:

### 1. Question

Example:

> Can Foundation Models reliably route Russian automotive notes into
> typed PitStop drafts?

### 2. Official source

Record: - documentation; - WWDC session; - sample code.

Prefer first-party sources.

### 3. Minimal isolated spike

No SwiftData mutation.

No production UI unless needed.

### 4. Test/evaluation

Define success before running the experiment.

### 5. Result

One of:

``` text
ADOPT
ADOPT WITH BOUNDARY
DEFER
REJECT
```

### 6. Production integration

Only after result.

## Foundation Models curriculum

1.  Model availability.
2.  Session instructions.
3.  Guided generation.
4.  Structured drafts.
5.  Streaming only if UX needs it.
6.  Tool calling.
7.  Tool-call evaluations.
8.  Core Spotlight grounding investigation.
9.  Adapters only if prompt/guided generation/tool calling demonstrably
    fail and a suitable dataset exists.

Each stage requires a PitStop-specific artifact.

## Swift Testing curriculum

Use the maintenance engine to practice: - suites; - descriptive tests; -
`#expect`; - `#require`; - parameterized tests; - tags; - concurrency
behavior; - test organization.

Learning success: - tests become clearer and less duplicated.

Failure: - framework adoption causes a rewrite without product benefit.

## Observability curriculum

Study: - unified logging; - privacy-aware log interpolation; - Logger
categories; - signposts; - Instruments; - MetricKit; - Crashlytics
correlation.

Lab output: - one documented end-to-end trace for `Tell PitStop`; - one
documented end-to-end trace for maintenance snapshot rebuild.

## App Intents curriculum

Do not start from Siri UI.

Start from domain commands: - add note; - get context notes; - update
odometer; - record event; - get maintenance status.

Then map to App Intents.

## SwiftData/CloudKit curriculum

Sequence: 1. current schema audit; 2. migration behavior; 3.
query/projection boundaries; 4. CloudKit-compatible schema review; 5.
sync conflict experiment; 6. asset strategy.

Do not turn the production database into a schema playground without
migration fixtures.

## Learning notes format

Each lab note:

``` text
# Technology / API

## Product question
## What I expected
## Official sources
## Spike
## Tests/evaluations
## Result
## What failed
## What I learned
## PitStop decision
## Follow-up
```

The repository should become interview-quality evidence of applied
engineering judgment, not a list of technologies.
