# PitStop Engineering & Product Documentation

**Status:** working source of truth\
**Project mode:** product development + engineering laboratory +
learning system\
**Primary platform:** iOS\
**Current product boundary:** one vehicle per user in research beta\
**Core product statement:** **A smart memory for your car.**

## Purpose

This documentation is the authoritative working plan for PitStop. It
separates product hypotheses, domain decisions, implementation tasks,
experiments, telemetry, and learning notes.

PitStop is intentionally developed in three modes at once:

1.  **Product** --- solve a real recurring problem for a car owner.
2.  **Laboratory** --- test Foundation Models, SwiftData, App Intents,
    WidgetKit, CloudKit and modern Apple APIs on a real domain.
3.  **Textbook** --- record why a technology was selected, how it works,
    what failed, and what was learned.

These modes must not be mixed in production behavior. Experimental
technology is allowed behind an explicit boundary or feature flag.
Product correctness remains deterministic.

## Product model

``` text
STATUS                 NOTES                  HISTORY
What matters now       What I don't want      What happened
                       to forget

                    TELL PITSTOP
                 text / voice / document
```

Core lifecycle:

``` text
THINK → NOTE
DO    → HISTORY
FACTS + POLICIES → STATUS
```

Maintenance lifecycle:

``` text
Vehicle facts
    ↓
Maintenance knowledge
    ↓
Effective per-operation policies
    ↓
Independent maintenance cycles
    ↓
Service Planner
    ↓
Service Plan
    ↓
Actual Service Visit
    ↓
History + cycle resets for confirmed work only
```

## Documentation map

-   `01_PRODUCT_CHARTER.md` --- product scope, principles,
    success/failure criteria.
-   `02_DOMAIN_MODEL.md` --- domain language and source-of-truth
    boundaries.
-   `03_MAINTENANCE_ENGINE.md` --- anchors, procedures, service
    composition and rule engine.
-   `04_AI_ARCHITECTURE.md` --- Foundation Models boundaries, drafts,
    evaluations and fallback.
-   `05_ENGINEERING_STANDARD.md` --- TDD, test-first workflow, atomic
    tasks, Definition of Done.
-   `06_OBSERVABILITY.md` --- professional logging, signposts, crash
    diagnostics and privacy.
-   `07_ANALYTICS.md` --- Firebase Analytics event taxonomy and research
    metrics.
-   `08_ROADMAP.md` --- phased atomic development plan with acceptance
    gates.
-   `09_INVESTIGATIONS.md` --- explicit unknowns and decision criteria.
-   `10_ADR_001_MAINTENANCE_ANCHORS.md` --- architecture decision
    record.
-   `11_CURRENT_DOMAIN_AUDIT.md` --- audit of the current public
    repository model.
-   `12_LEARNING_LAB.md` --- learning protocol for new Apple/AI
    technology.
-   `13_TEST_STRATEGY.md` --- test pyramid, fixtures, golden cases and
    AI evaluations.
-   `14_TELEMETRY_CONTRACT.md` --- logging/analytics naming and data
    policy.
-   `15_RELEASE_AND_BETA.md` --- TestFlight research beta and release
    gates.
-   `16_TASK_TEMPLATE.md` --- mandatory template for implementation
    tasks.

## Authority rules

When documents conflict:

1.  Accepted ADR.
2.  Product Charter.
3.  Domain Model.
4.  Engineering Standard.
5.  Roadmap.
6.  Investigation notes.
7.  Historical brainstorm documents.

A brainstorm is not an implementation specification.

## Immediate instruction

Do not perform a broad SwiftData rewrite.

The next engineering sequence is:

``` text
current domain audit verification
→ ADR acceptance
→ pure Swift maintenance rule spike
→ tests
→ adapters from current data
→ MaintenanceSnapshot
→ one-glance status
```

No implementation task is considered complete without acceptance
criteria, tests, logging review, analytics review where relevant, and
documentation update.

## Product identity and public development

Additional source documents:

-   `17_PRODUCT_DESIGN.md` --- friendly visual direction, semantic color
    strategy and design validation.
-   `18_NAMING_EXPLORATION.md` --- PitStop name evaluation and rename
    gate.
-   `19_DEVELOPMENT_DIARY_AND_LINKEDIN.md` --- engineering diary, weekly
    LinkedIn workflow and metrics.

The current working name remains **PitStop** until beta evidence
justifies a naming sprint.

## Product engineering operating system

-   `20_COMPETITIVE_RESEARCH.md` --- competitor/OSS landscape, feature
    matrix, strengths and weaknesses.
-   `21_ANALYTICS_SERVICE_DECISION.md` --- analytics comparison and
    PostHog beta candidate decision.
-   `22_LOGGING_DECISION.md` --- DEBUG-only typed OSLog strategy; no
    custom logging framework.
-   `23_ENGINEERING_QUALITY_AND_CI.md` --- Instruments gates, quality
    ledger, hooks and GitHub Actions.
-   `24_PROJECT_MANAGEMENT_AND_GITFLOW.md` --- GitHub Projects, issues,
    atomic PRs and trunk-based GitHub Flow.
-   `25_MODULAR_ARCHITECTURE.md` --- feature modules, domain boundaries,
    MVVM + Coordinator and DI rules.
-   `26_DESIGN_SYSTEM.md` --- minimal semantic DesignSystem module.
-   `27_APP_ICON_STRATEGY.md` --- immediate PitStop icon and later
    alternate icon policy.

Current analytics candidate: **PostHog**, behind typed feature analytics
protocols, pending a vertical-slice spike.

Current logging decision: **OSLog.Logger with a tiny DEBUG-only typed
facade**. Do not build a logging framework.
