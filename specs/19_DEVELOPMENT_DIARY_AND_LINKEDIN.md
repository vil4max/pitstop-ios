# Development Diary and LinkedIn Research Log

## Objective

PitStop development should leave a public professional narrative.

The goal is not "become a creator."

The goal is:

> show applied Senior iOS engineering judgment while building a real
> AI-enabled iOS product.

Publishing cadence:

``` text
one LinkedIn post per week
```

This is intentionally sustainable during job search and development.

## Two separate artifacts

### Private engineering diary

Stored in the repository.

Purpose: - preserve decisions; - capture failed experiments; - produce
future ADRs/posts/interview stories.

### Public LinkedIn post

A curated weekly story.

Purpose: - professional visibility; - demonstrate iOS/AI/product
thinking; - create a consistent body of work.

Do not write the LinkedIn post directly from git diff.

## Development diary structure

Suggested path:

``` text
docs/diary/
YYYY-MM-DD-topic.md
```

Template:

``` text
# Topic

## Question
What was I trying to understand?

## Product context
Why does PitStop need this?

## Initial assumption
What did I believe before implementation?

## Experiment / task
What did I build or inspect?

## Evidence
Tests, evaluation numbers, analytics, screenshots, traces.

## Result
What happened?

## What failed
Be specific.

## Decision
ADOPT / ADOPT WITH BOUNDARY / DEFER / REJECT

## What I learned
Technical explanation in my own words.

## LinkedIn angle
One sentence. What is the useful professional lesson?
```

## Weekly post selection

At the end of the week, review diary entries.

Score each candidate 1--5:

``` text
useful to another iOS engineer
contains a concrete decision
contains evidence/number
can be explained without NDA
shows product impact
```

Publish the highest-value story.

If no story scores well, publish nothing or use a learning recap. Do not
invent drama.

## Content pillars

### 1. iOS architecture from a real product

Examples: - why ServiceVisit should not own maintenance schedules; -
separating ServicePlan from actual ServiceVisit; - why independent
maintenance cycles compose into one practical visit.

### 2. AI without chat UI

Examples: - using a local LLM as an input interpreter; - why the model
creates drafts but cannot mutate SwiftData; - deterministic Swift
engine + LLM attention editor.

### 3. Test-first product development

Examples: - one invariant: completing oil cannot reset DSG; - how
parameterized tests shaped MaintenanceRule; - a regression test from a
real beta bug.

### 4. Apple technology laboratory

Examples: - Foundation Models guided generation evaluation; - App
Intents boundary; - Swift Testing; - SwiftData migration; - WidgetKit
one-glance state.

### 5. Product decisions by evidence

Examples: - due-nearby grouping acceptance rate; - natural-input draft
edit rate; - why a feature was removed after five-car beta.

## Post format

Recommended structure:

``` text
CONCRETE OBSERVATION

I was building X in PitStop.

ASSUMPTION

I initially modeled it as Y.

PROBLEM

Real usage showed Z.

DECISION

I changed the domain boundary to ...

EVIDENCE

N tests / N phrases / beta metric / before-after behavior.

LESSON

One transferable engineering conclusion.
```

Avoid: - motivational filler; - "AI is changing everything"; -
pretending a five-person beta is statistically representative; -
excessive tool-name lists; - fake controversy; - posts whose only point
is "I used technology X."

## Weekly metrics log

Create:

``` text
docs/diary/linkedin-metrics.csv
```

One row per post after a fixed observation window.

Initial observation windows:

``` text
24 hours
7 days
```

Track if visible in LinkedIn analytics:

``` text
post_date
topic
content_pillar
format
impressions_24h
impressions_7d
members_reached_7d
reactions_7d
comments_7d
reposts_7d
saves_7d
sends_7d
profile_views_delta_7d
followers_delta_7d
job_or_recruiter_conversations
notes
```

Do not optimize for impressions alone.

## AI-assisted analytics review metrics

When documenting an `AIA-001` or manual AI-assisted analytics review in
the private diary, record:

``` text
review_duration_minutes
useful_new_hypothesis = yes | no
missing_evidence_found = yes | no
unsupported_claim_count
human_decision_changed = yes | no
investigation_created = yes | no
```

These are development-process learning metrics, not product analytics
events. Do not send them to PostHog.

See `30_AI_PRODUCT_ANALYTICS.md` and `12_LEARNING_LAB.md`.

## Derived metrics

Calculate locally:

``` text
engagement_rate =
(reactions + comments + reposts) / impressions

save_rate =
saves / impressions

conversation_rate =
job_or_recruiter_conversations / members_reached
```

Use these only as directional metrics. LinkedIn metric definitions and
available fields may change.

## Metrics that matter for Max's goal

Priority:

1.  Recruiter/job conversations attributable to a post.
2.  Profile-view change after publication.
3.  Members reached / audience expansion.
4.  Saves and sends for technical usefulness.
5.  Comments with substantive engineering discussion.
6.  Impressions.

A 2,000-impression post that creates two relevant Senior iOS
conversations is more valuable than a 50,000-impression generic AI post.

## Monthly content review

Every four posts:

``` text
Which pillar produced profile/recruiter movement?
Which topic was saved/shared?
Which post attracted iOS engineers?
Which post attracted generic AI audience?
Which format was easiest to sustain?
What should be repeated?
What should stop?
```

Do not change strategy after one weak post.

## PitStop metrics as post material

Interesting numbers should come from engineering/product work:

``` text
50 evaluation phrases
96% critical numeric extraction
12 maintenance invariants
8 independent maintenance operations
3 pipeline stages removed
0 silent AI mutations
5 real cars in beta
X% due-nearby suggestions accepted
X% drafts saved without edits
median interpretation latency
number of unknown-baseline cases found
```

Rules: - numbers must be reproducible; - label fixture/evaluation
numbers correctly; - never present five-user beta data as market
research; - never publish private friend/car details; - never expose
VIN, exact service history, raw notes or transcripts.

## Post backlog

Maintain:

``` text
docs/diary/LINKEDIN_BACKLOG.md
```

Each idea:

``` text
Title / hook
Diary source
Content pillar
Evidence available
Missing evidence
Status
```

Status:

``` text
idea
needs_evidence
ready
published
discarded
```

## Success criteria after 12 weeks

-   8--12 substantive posts published;
-   a repeatable diary → evidence → post workflow exists;
-   at least three posts contain concrete engineering measurements;
-   profile/recruiter conversation trend is tracked;
-   the public narrative clearly connects Senior iOS + practical AI +
    product engineering.

Failure: - weekly posting becomes a separate content job; - posts are
generic AI commentary; - metrics are copied manually without influencing
topic selection; - product decisions are distorted to create content.

## English ownership rule

Max writes the first LinkedIn draft in English.

The assistant does not ghostwrite the initial post.

Review workflow:

``` text
Max writes My English Draft
→ language review
→ explain recurring B1→B2 errors
→ preserve Max's wording and technical thought
→ minimal polish
→ Max approves final text
```

Diary entries intended for publication add:

``` text
## My English draft
## Language review notes
## Recurring English pattern
```

Language progress is part of the development diary.
