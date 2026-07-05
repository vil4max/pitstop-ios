# AI-Assisted Product Analytics

**Status:** staged product-development hypothesis\
**Decision type:** reversible workflow architecture\
**Depends on:** `21_ANALYTICS_SERVICE_DECISION.md`,
`29_ANALYTICS_QUESTIONS.md`
**Research freshness:** 2026-07-05

## Decision

PitStop should treat analytics as an **evidence layer for AI-assisted
product investigation**, not only as dashboards inspected manually.

The target product-development loop is:

``` text
Product Question Registry
→ Typed Semantic Events
→ PostHog Evidence Layer
→ Deterministic Query / Insight
→ Structured Evidence
→ AI Product Analyst
→ Evidence-backed Hypotheses
→ Human Decision
→ Investigation / Product Task
→ Experiment or Product Change
→ New Evidence
```

This does **not** make PitStop a self-driving product organization.

AI may inspect evidence, summarize patterns, compare results with
explicit research thresholds, and propose investigations.

AI must not autonomously: - change product behavior; - change
maintenance rules; - enable feature flags; - create or merge production
code; - redefine success criteria after seeing results; - silently
create analytics events; - treat a five-user beta as statistically
significant; - convert correlation into causation.

The owner remains the product decision authority.

## Architectural principle

PitStop already applies this AI principle to product state:

> AI interprets truth. AI does not own truth.

For maintenance:

``` text
MaintenanceDomain
→ deterministic vehicle state
→ AI may explain or compose a draft
```

For product analytics:

``` text
Analytics engine
→ deterministic evidence
→ AI may analyze, explain and propose hypotheses
```

The same trust boundary applies in both systems.

## Why this exists

Traditional analytics workflow:

``` text
events
→ dashboards
→ human manually searches charts
→ human notices a pattern
→ human forms a hypothesis
```

PitStop's learning-lab hypothesis is:

``` text
explicit product question
→ deterministic analytics evidence
→ AI-assisted investigation
→ human product decision
```

The expected benefit is not "AI makes product decisions."

The expected benefit is:

-   lower friction when investigating small product questions;
-   repeatable evidence reviews;
-   explicit connection between product questions and telemetry;
-   faster comparison of quantitative and qualitative beta evidence;
-   a development diary of hypotheses, evidence and decisions;
-   practical experience building an AI-assisted product-engineering
    loop.

## Source of truth boundaries

### `29_ANALYTICS_QUESTIONS.md`

Owns: - product questions; - provisional research thresholds; - required
evidence; - decision rules; - qualitative questions.

AI must not silently rewrite these rules while analyzing results.

### `07_ANALYTICS.md`

Owns: - event taxonomy; - event semantics; - bounded event properties; -
funnels derived from product questions.

Provider selection is not owned here.

### `14_TELEMETRY_CONTRACT.md`

Owns: - privacy/data classification; - prohibited raw telemetry; -
bounded telemetry rules; - telemetry change gate.

AI access does not weaken this contract.

### `21_ANALYTICS_SERVICE_DECISION.md`

Owns: - analytics provider decision; - PostHog candidate status; -
provider boundary; - P0 SDK configuration.

### This document

Owns: - AI-assisted analytics workflow; - AI analyst trust boundary; -
structured evidence contract; - staged adoption; - human approval gates.

## Current platform direction

PostHog remains the current beta analytics candidate pending `ANL-001`.

Official references:

-   https://posthog.com/
-   https://posthog.com/docs
-   https://posthog.com/ai
-   https://posthog.com/tutorials/mcp-analytics

Current PostHog public material positions product analytics as
event-based analysis with visualization or SQL and also provides
AI-assisted product analysis. PostHog also publishes MCP-oriented
workflows for bringing analytics into AI-enabled engineering tools.

This strengthens the PostHog candidate decision, but does not remove the
existing spike requirement.

The decision remains:

``` text
ANL-001
→ validate iOS integration and event boundary
→ ADOPT / ADOPT WITH BOUNDARY / FALL BACK
```

Do not select PostHog only because it has AI or MCP capabilities.

The base analytics evidence layer must be useful without AI.

## Evidence-first rule

The LLM must not infer product metrics from raw event prose.

Preferred flow:

``` text
PostHog / HogQL / saved insight
→ deterministic result
→ structured evidence
→ LLM interpretation
```

Bad:

``` text
export thousands of raw events
→ paste into LLM
→ "find something interesting"
```

Good:

``` text
AQ-001
→ run explicit query
→ return cohort counts and time window
→ provide threshold and known caveats
→ ask AI to interpret evidence
```

The AI analyst receives facts and constraints.

It does not become the metric engine.

## Structured evidence contract

AI analysis should consume a bounded evidence package.

Conceptual model:

``` text
AnalyticsEvidence
├── questionID
├── questionVersion
├── generatedAt
├── timeWindow
├── cohortDefinition
├── sampleSize
├── queryReference
├── metrics
├── qualitativeEvidenceReferences
├── researchThreshold
├── knownLimitations
└── dataFreshness
```

Illustrative representation:

``` text
question_id: AQ-001
question_version: 1
time_window: 2026-08-01...2026-08-14
cohort: invited_beta_users_excluding_owner
sample_size: 5
query_reference: posthog_insight_context_reopen_v1

metrics:
  invited_users: 5
  users_created_note: 4
  users_reopened_context: 1

research_threshold:
  type: provisional_research_threshold
  value: 2_of_5

known_limitations:
  - five-user qualitative beta
  - no statistical significance
  - context discoverability and context value are confounded

data_freshness:
  status: complete_for_window
```

The exact implementation format is deferred.

Do not create an `AnalyticsEvidence` Swift type until a real runtime
consumer requires it.

For the first iteration, a Markdown or generated JSON report is
sufficient.

## AI Product Analyst responsibilities

The AI analyst may:

-   read one explicit analytics question;
-   inspect its threshold and decision rule;
-   inspect deterministic query results;
-   compare evidence with the predefined threshold;
-   identify missing evidence;
-   identify confounded variables;
-   propose multiple competing hypotheses;
-   recommend the next investigation;
-   connect quantitative evidence with explicitly provided beta
    interview notes;
-   draft a GitHub investigation issue for human approval;
-   produce a development-diary summary.

The AI analyst should prefer:

``` text
Observed evidence
→ limitation
→ possible explanations
→ next discriminating investigation
```

Example:

``` text
AQ-001 — Contextual Recall Value

Observed evidence:
4 of 5 beta users created at least one Note.
1 of 5 independently reopened a NoteContext.

Research threshold:
2 of 5 independently reopen a context.

Status:
WEAK SIGNAL

Known limitation:
The current data cannot distinguish low contextual-memory value
from poor context-entry discoverability.

Competing hypotheses:
H1 — Context entry points are not discoverable.
H2 — Notes are classified into unexpected contexts.
H3 — Contextual recall does not provide enough value.

Recommended next investigation:
Inspect `note_context_opened.source` only if that property is already
approved by the telemetry change gate.
Otherwise run a short moderated retrieval test.

Do not change the Note domain model yet.
```

The AI analyst must distinguish: - observation; - metric; - threshold; -
interpretation; - hypothesis; - recommendation.

These must not be collapsed into one confident narrative.

## AI Product Analyst prohibited behavior

The AI analyst must not:

-   invent missing events;
-   assume an event means something not defined in the event registry;
-   use raw Note text, transcript text, VIN, plate, invoice text or
    other prohibited telemetry;
-   request broader telemetry without a product question;
-   redefine event semantics;
-   infer user intent from an event name alone when the taxonomy is
    ambiguous;
-   call a research threshold a KPI benchmark;
-   claim statistical significance for the five-user beta;
-   claim causality from correlation;
-   select the "best" hypothesis without discriminating evidence;
-   open implementation work as approved scope without human
    confirmation.

## Analytics question execution flow

For every AI-assisted review:

``` text
1. Select one AQ-* question.
2. Load the authoritative question definition.
3. Verify required events exist in the telemetry registry.
4. Verify event semantics and privacy contract.
5. Run or load a deterministic query/insight.
6. Record cohort, time window and sample size.
7. Build structured evidence.
8. Ask AI to analyze only the provided evidence.
9. Require limitations and competing hypotheses.
10. Human reviews the analysis.
11. Human selects:
    - NO ACTION
    - MORE EVIDENCE
    - INVESTIGATE
    - PRODUCT CHANGE
12. Only after approval may a GitHub Issue be created.
```

## GitHub workflow integration

Target future flow:

``` text
AQ-001 evidence
→ AI analyst report
→ human review
→ approved investigation
→ GitHub Issue
→ atomic branch
→ PR
→ CI
→ TestFlight
→ new evidence window
→ AQ-001 re-evaluation
```

An AI-generated issue is a draft until the owner approves it.

Suggested issue metadata:

``` text
type: investigation
source: analytics
analytics_question: AQ-001
evidence_window: 2026-08-01...2026-08-14
evidence_reference: <saved insight/report>
decision_owner: Max
```

Do not automatically assign implementation priority from an AI report.

## Quantitative and qualitative evidence

PitStop's first beta has approximately five users.

Therefore:

> Qualitative evidence is primary. Product analytics supports
> investigation and recall; it does not create statistical certainty.

The AI analyst may combine:

``` text
bounded product analytics
+
explicit beta interview notes
+
release/change history
```

But these sources must remain distinguishable.

Example:

``` text
Quantitative evidence:
1/5 users independently reopened a context.

Qualitative evidence:
2 users said they did not notice the context entry point.

Release context:
The context card was added in build 14.

Interpretation:
Discoverability is a stronger current hypothesis than domain-model failure.

Confidence:
Low-to-medium due to sample size.
```

Do not send raw private user content to an external model merely to
enrich analysis.

Interview notes must be manually sanitized or summarized before AI
analysis if they contain personal or sensitive content.

## AI observability is a separate concern

Do not confuse:

``` text
AI product analytics
```

with:

``` text
AI runtime observability
```

AI product analytics asks:

> Is the AI-assisted product workflow useful to users?

Examples: - draft confirmation rate; - semantic edit rate; - rejection
rate; - repeated use.

AI runtime observability asks:

> How did a model interaction execute?

Examples: - generation latency; - model availability; - failure
reason; - token/cost data for remote models; - trace/generation
relationships.

PitStop P0 does not automatically enable an AI observability product.

If Foundation Models or a remote model becomes a real product
dependency, create a separate investigation and privacy review.

Google AI Studio Logs and similar model-execution logging surfaces are
research references for AI observability, not a replacement for PitStop
product analytics.

## MCP position

MCP is not required for PitStop application runtime.

Potential future use:

``` text
Cursor / AI engineering environment
→ PostHog MCP
→ approved analytics project
→ read analytics evidence
→ draft investigation report
```

This is a development-tool integration.

It is not part of the iOS app architecture.

P0 application code must not depend on MCP.

Before enabling an analytics MCP integration:

-   review available tool permissions;
-   use least-privilege credentials;
-   prefer read-only analytics access where supported;
-   verify project/environment selection;
-   verify whether tools can mutate insights, flags, experiments or
    annotations;
-   do not expose production secrets in repository configuration;
-   document credential storage;
-   test queries manually;
-   require human approval before any mutating analytics action.

The initial AI-assisted analytics review may be performed manually
without MCP.

## Staged adoption

### Stage 0 --- Product questions

Status: `P0`

Required: - normalize analytics provider contradictions; -
maintain `29_ANALYTICS_QUESTIONS.md`; - connect each P0 event to
a product question, release requirement or explicit investigation.

Success:

> We can explain why every collected P0 product event exists.

Failure:

> Events are collected because they may be useful later.

### Stage 1 --- Typed events and PostHog evidence layer

Status: `P0`

Required: - complete `ANL-001`; - preserve typed feature analytics
APIs; - PostHog remains isolated in its adapter; - build one
reproducible insight/query for one AQ question.

Success:

> The same question produces a repeatable evidence result without AI
> interpretation.

Failure:

> The answer depends on manually clicking dashboards until something
> looks interesting.

### Stage 2 --- Manual AI-assisted review

Status: `P0 beta / learning lab`

Select one question, preferably `AQ-001`.

Manually: - export or summarize deterministic evidence; - create a
bounded evidence package; - ask an AI analyst to interpret it; - compare
AI output with the owner's own product analysis; - record where the AI
invented, overclaimed or found a useful alternative hypothesis.

Success:

> AI reduces investigation friction or produces a useful competing
> hypothesis while staying evidence-bound.

Failure:

> AI mainly rewrites the dashboard in prose or invents causal stories.

### Stage 3 --- PostHog AI / MCP investigation

Status: `INVESTIGATE`

Only after real beta events exist.

Evaluate: - query ergonomics; - schema understanding; -
reproducibility; - permission scope; - evidence citation/reference
quality; - hallucination/overclaim rate; - whether the workflow is
materially better than manual Stage 2.

Decision:

``` text
ADOPT FOR READ-ONLY INVESTIGATION
ADOPT WITH RESTRICTED WORKFLOW
KEEP MANUAL AI REVIEW
REJECT
```

### Stage 4 --- Investigation draft automation

Status: `P1 / DEFERRED`

Potential flow:

``` text
scheduled or manual AQ review
→ evidence package
→ AI analysis
→ investigation issue draft
→ human approval
```

No autonomous implementation.

No autonomous feature-flag mutation.

No autonomous product-priority change.

## First experiment

### `AIA-001 — AQ-001 AI-assisted analytics review`

Prerequisites: - `ANL-001` completed with PostHog adopted or adopted
with boundary; - `AQ-001` exists; - `note_created` semantics are
stable; - `note_context_opened` semantics are stable; - real beta
evidence exists.

Procedure:

``` text
1. Run AQ-001 deterministic query.
2. Record time window, cohort and sample size.
3. Create one structured evidence package.
4. Write Max's own interpretation before seeing AI analysis.
5. Give the AI only:
   - AQ-001 definition;
   - telemetry semantics required for AQ-001;
   - structured evidence;
   - known release context.
6. Request:
   - observations;
   - limitations;
   - competing hypotheses;
   - next discriminating investigation;
   - explicit confidence.
7. Compare human and AI analyses.
8. Record useful additions and unsupported claims.
```

Do not ask:

> Analyze my analytics and tell me what to build.

Ask:

> Given AQ-001, its predefined threshold, event semantics and this
> bounded evidence package, identify observations, limitations,
> competing hypotheses and the next investigation that best separates
> those hypotheses.

### Success criteria

At least one: - AI identifies a plausible competing hypothesis Max did
not record; - AI finds a missing evidence requirement before a product
change; - AI materially reduces time required to produce a structured
investigation report.

And all: - no invented metric; - no invented event; - no prohibited raw
data required; - no unsupported causal claim presented as fact; - final
product decision remains human-owned.

### Failure criteria

-   AI output is only prose reformulation of metrics;
-   AI repeatedly ignores the small sample limitation;
-   AI invents event semantics;
-   useful analysis requires prohibited raw content;
-   MCP/tool permissions are broader than justified;
-   workflow costs more attention than manual analysis.

## Analytics report template

``` text
# AI Product Analytics Review

Question:
AQ-XXX — <name>

Question version:
<version>

Evidence window:
<start>...<end>

Cohort:
<definition>

Sample size:
<n>

Deterministic evidence:
- <metric/result>
- <metric/result>

Research threshold:
<predefined threshold or none>

Qualitative evidence:
- <sanitized evidence reference or none>

Known limitations:
- <limitation>

Observed:
- <evidence-backed observation>

Competing hypotheses:
- H1 — <hypothesis>
- H2 — <hypothesis>
- H3 — <hypothesis>

Next discriminating investigation:
<investigation>

AI confidence:
LOW | MEDIUM | HIGH

Human decision:
NO ACTION | MORE EVIDENCE | INVESTIGATE | PRODUCT CHANGE

Decision owner:
Max

Decision notes:
<notes>
```

## Metrics for the analytics laboratory itself

The AI-assisted analytics workflow is also a hypothesis.

Track manually in the learning diary:

``` text
review_duration_minutes
useful_new_hypothesis = yes | no
missing_evidence_found = yes | no
unsupported_claim_count
human_decision_changed = yes | no
investigation_created = yes | no
```

Do not send these as product analytics events.

They are development-process learning metrics.

## Privacy and security

The AI analytics workflow inherits the strictest relevant telemetry
rule.

Never provide by default: - raw Note text; - raw prompts; - voice
transcripts; - VIN; - license plate; - photos; - OCR text; - invoice
text; - exact free-text beta feedback; - external service credentials.

Prefer: - enums; - buckets; - counts; - boolean flags; - bounded reason
codes; - sanitized qualitative summaries.

If a future AI investigation genuinely requires raw user content, stop
and create a separate privacy/product decision.

## Non-goals

This specification does not authorize:

-   an autonomous product manager agent;
-   automated roadmap prioritization;
-   automatic feature implementation from analytics;
-   autonomous GitHub issue creation;
-   autonomous feature-flag changes;
-   a generic analytics-agent framework;
-   a custom MCP server;
-   runtime MCP inside PitStop;
-   replacing PostHog queries with LLM arithmetic;
-   collecting more telemetry for AI convenience.

## Acceptance criteria

This specification is satisfied when:

-   AI-assisted analytics is documented as an evidence-interpretation
    layer;
-   deterministic analytics remains the metric source of truth;
-   AI and human decision boundaries are explicit;
-   `29_ANALYTICS_QUESTIONS.md` is the question/threshold source of
    truth;
-   one bounded evidence contract is documented;
-   MCP is explicitly outside iOS runtime architecture;
-   a staged adoption plan exists;
-   `AIA-001` is defined;
-   privacy constraints are inherited from `14_TELEMETRY_CONTRACT.md`;
-   five-user beta limitations are explicit;
-   no autonomous product mutation is authorized.

## Re-evaluation triggers

Review this decision if:

-   PostHog is not adopted after `ANL-001`;
-   PostHog AI/MCP capabilities or permissions materially change;
-   analytics access cannot be made sufficiently narrow;
-   beta evidence shows no recurring product questions worth automating;
-   manual analytics review is already low-friction;
-   AI analysis repeatedly overclaims despite structured evidence;
-   a second analytics provider becomes real;
-   PitStop begins processing sensitive raw content for analytics.

## Final principle

> Product analytics establishes evidence. AI expands the investigation.
> The owner makes the decision.
