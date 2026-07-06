# Product Analytics Question Registry

**Status:** `P0`\
**Decision type:** product-research registry\
**Depends on:** `07_ANALYTICS.md`, `14_TELEMETRY_CONTRACT.md`\
**Referenced by:** `30_AI_PRODUCT_ANALYTICS.md`

## Purpose

This document is the authoritative source for:

-   `AQ-*` product questions;
-   provisional research thresholds;
-   required evidence;
-   decision rules;
-   qualitative product questions.

Analytics starts with an explicit product question. Events exist to answer
a product question, satisfy a release/diagnostic requirement, or support
an approved investigation.

Provider selection is owned by `21_ANALYTICS_SERVICE_DECISION.md`.

Event taxonomy is owned by `07_ANALYTICS.md`.

## AI analysis rule

> AI analysis must not silently redefine a question, threshold, or
> decision rule after seeing evidence.

AI may interpret evidence against the definitions in this document. AI
must not rewrite thresholds, cohorts, or success criteria to make an
experiment appear successful.

## Threshold classification

All numeric thresholds in this document are:

``` text
provisional research thresholds
not statistically significant product benchmarks
```

The five-car research beta cannot support statistical significance
claims.

## Question format

Each `AQ-*` entry defines:

``` text
question_id
question_version
product_question
required_events
required_evidence
research_threshold
decision_rule
qualitative_questions
status
```

## AQ-001 — Contextual recall value

**Question version:** 1\
**Status:** `P0`

### Product question

Do context views provide recall value after a user creates Notes with
canonical context?

### Required events

``` text
note_created
note_context_opened
```

Optional funnel support:

``` text
note_archived
```

Event semantics are defined in `07_ANALYTICS.md`.

### Required evidence

Deterministic cohort evidence for the beta window:

``` text
invited_beta_users_excluding_owner
users_created_at_least_one_note
users_independently_reopened_a_context
```

Independently reopened means the user opened a context that already had
active notes without a moderated prompt during the observation window.

### Research threshold

``` text
type: provisional_research_threshold
value: 2_of_5
description: at least 2 of 5 invited beta users independently reopen a
             context with existing notes
```

This is a research signal threshold, not a KPI benchmark.

### Decision rule

``` text
PASS SIGNAL   → threshold met; investigate whether value is strong
                enough to keep context UX investment
WEAK SIGNAL   → below threshold; run qualitative retrieval/discoverability
                investigation before changing domain model
INCONCLUSIVE  → required events missing or cohort too small to interpret
```

Do not change the Note domain model based on analytics alone.

### Qualitative questions

-   Did the user notice the context entry point?
-   Did the user remember creating the note before reopening the context?
-   Was recall useful when it happened?

### Known confounds

-   context discoverability;
-   context classification accuracy;
-   small sample size.

## AQ-002 — Lightweight vehicle setup

**Question version:** 1\
**Status:** `P0`

### Product question

Do users complete lightweight vehicle setup without abandoning onboarding?

### Required events

``` text
car_context_first_enriched
odometer_updated
```

### Required evidence

``` text
onboarding_completion_rate
median_setup_duration_bucket
odometer_present_rate_at_setup_completion
```

### Research threshold

``` text
type: provisional_research_threshold
value: 4_of_5
description: at least 4 of 5 invited beta users complete onboarding
```

### Decision rule

If completion is low, investigate mandatory fields, seeded-data
confusion, and onboarding copy before adding setup steps.

## AQ-003 — Real Notes and History facts

**Question version:** 1\
**Status:** `P0`

### Product question

Do users create real Notes or History facts rather than only browsing
seed/demo content?

### Required events

``` text
note_created
history_event_created
```

### Required evidence

``` text
users_with_at_least_one_user_originated_note_or_history_event
repeat_creation_within_14_days
```

### Research threshold

``` text
type: provisional_research_threshold
value: 3_of_5
description: at least 3 of 5 invited beta users create at least one
             non-seeded note or history event
```

### Decision rule

If below threshold, prioritize input friction, value clarity, and demo
vs real-data boundaries before expanding Note types.

## AQ-004 — Remember input friction

**Question version:** 1\
**Status:** `P0`

### Product question

Does Remember reduce input friction for supported intents?

### Required events

``` text
input_interpretation_completed
draft_saved
draft_cancelled
```

### Required evidence

``` text
supported_intent_draft_rate
draft_save_rate
draft_cancel_rate
edit_before_save_rate
latency_bucket_distribution
```

### Research threshold

``` text
type: provisional_research_threshold
value: save_rate_gte_70_percent_on_supported_intents
description: provisional beta target from controlled evaluation; not a
             production KPI
```

Engineering quality gates for interpreter accuracy remain in
`04_AI_ARCHITECTURE.md` and are separate from this product question.

### Decision rule

High cancel rate or repeated structural edits trigger interpreter UX and
evaluation review, not automatic feature removal.

## AQ-005 — Maintenance status trust

**Question version:** 1\
**Status:** `P0`

### Product question

Do users trust and understand maintenance status presentation?

### Required events

``` text
maintenance_status_viewed
```

### Required evidence

``` text
repeat_status_view_rate
unknown_count_bucket_distribution
qualitative_interview_notes_on_status_clarity
```

### Research threshold

No numeric pass/fail threshold yet.

Use qualitative beta interviews as primary evidence until status UX
stabilizes.

### Decision rule

Confusion about unknown/due semantics triggers copy and projection
review before adding AI explanations.

## AQ-006 — Service planner alignment

**Question version:** 1\
**Status:** `P0`

### Product question

Does the planner's suggested service scope match real user decisions?

### Required events

``` text
service_scope_viewed
service_plan_edited
```

### Required evidence

``` text
due_removed_count_bucket_distribution
nearby_removed_count_bucket_distribution
optional_added_removed_distribution
qualitative_review_of_removed_due_items
```

### Research threshold

``` text
type: provisional_research_threshold
value: due_nearby_removal_review_if_gt_30_percent
description: if more than 30% of due-nearby suggestions are removed,
             grouping rules require review
```

### Decision rule

Planner grouping changes require investigation evidence and domain
review, not analytics-only changes.

## Release and diagnostic requirements

Some events support release gates or diagnostics without a primary `AQ-*`
owner yet:

| Event / property need | Requirement | Status |
| --- | --- | --- |
| Analytics smoke validation before TestFlight | `15_RELEASE_AND_BETA.md` release gate | `P0` |
| Provider adapter verification (`ANL-001`) | `note_created`, `note_context_opened` smoke events | `P0` |

If an event lacks an `AQ-*` owner and no release/diagnostic requirement,
mark it `REVIEW` in `07_ANALYTICS.md` and do not collect it.

## Experiments

### `AIA-001 — AQ-001 AI-assisted analytics review`

**Status:** `P1` learning lab — not immediately executable

**Type:** learning-lab / product-development experiment

**Prerequisites:**

``` text
ANL-001 completed
AQ-001 stable
note_created semantics stable
note_context_opened semantics stable
real beta evidence exists
```

**Required comparison:**

``` text
Max writes his interpretation first
→ AI receives bounded evidence
→ compare human and AI analysis
```

**AI output must include:**

-   observations;
-   limitations;
-   competing hypotheses;
-   next discriminating investigation;
-   explicit confidence.

**Success:** useful analytical value without invented metrics, invented
events, or unsupported causal claims.

Workflow details: `30_AI_PRODUCT_ANALYTICS.md`.

Do not start `AIA-001` until all prerequisites are satisfied.

## Related documents

-   `07_ANALYTICS.md` — event taxonomy and P0 event ownership table
-   `21_ANALYTICS_SERVICE_DECISION.md` — analytics provider selection
-   `30_AI_PRODUCT_ANALYTICS.md` — AI-assisted analytics workflow
-   `14_TELEMETRY_CONTRACT.md` — privacy and telemetry channels
