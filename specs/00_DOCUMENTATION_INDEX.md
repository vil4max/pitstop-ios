# PitStop Documentation Index

This folder is the consolidated source of truth for PitStop.

## Start here

1.  `README.md`
2.  `01_PRODUCT_CHARTER.md`
3.  `08_ROADMAP.md`
4.  `11_CURRENT_DOMAIN_AUDIT.md`
5.  `25_MODULAR_ARCHITECTURE.md`

## Product and domain

-   `01_PRODUCT_CHARTER.md`
-   `02_DOMAIN_MODEL.md`
-   `03_MAINTENANCE_ENGINE.md`
-   `10_ADR_001_MAINTENANCE_ANCHORS.md`
-   `11_CURRENT_DOMAIN_AUDIT.md`

## AI and learning laboratory

-   `04_AI_ARCHITECTURE.md`
-   `12_LEARNING_LAB.md`
-   `30_AI_PRODUCT_ANALYTICS.md`

## Engineering, tests, observability and quality

-   `05_ENGINEERING_STANDARD.md`
-   `06_OBSERVABILITY.md`
-   `13_TEST_STRATEGY.md`
-   `14_TELEMETRY_CONTRACT.md`
-   `22_LOGGING_DECISION.md`
-   `23_ENGINEERING_QUALITY_AND_CI.md`

## Analytics and beta

-   `07_ANALYTICS.md`
-   `15_RELEASE_AND_BETA.md`
-   `21_ANALYTICS_SERVICE_DECISION.md`
-   `29_ANALYTICS_QUESTIONS.md`
-   `30_AI_PRODUCT_ANALYTICS.md`

## Planning and execution

-   `08_ROADMAP.md`
-   `09_INVESTIGATIONS.md`
-   `16_TASK_TEMPLATE.md`
-   `24_PROJECT_MANAGEMENT_AND_GITFLOW.md`

## Design, naming and identity

-   `17_PRODUCT_DESIGN.md`
-   `18_NAMING_EXPLORATION.md`
-   `26_DESIGN_SYSTEM.md`
-   `27_APP_ICON_STRATEGY.md`

## Research and development diary

-   `19_DEVELOPMENT_DIARY_AND_LINKEDIN.md`
-   `20_COMPETITIVE_RESEARCH.md`

## Architecture

-   `25_MODULAR_ARCHITECTURE.md`

## Current decisions

-   Working name: PitStop.
-   Existing seeded note-like cases, including film/wrap and floor mats,
    must be audited and preserved before Notes refactoring.
-   Architecture: feature modules + pure domain + infrastructure
    adapters + MVVM + Coordinator + initializer DI.
-   Analytics candidate: PostHog, pending `ANL-001` vertical-slice validation.
-   Product analytics questions: `29_ANALYTICS_QUESTIONS.md`.
-   AI-assisted analytics workflow: `30_AI_PRODUCT_ANALYTICS.md` (`AIA-001`
    staged after real beta evidence).
-   Logging: DEBUG-only typed facade over OSLog.Logger; no custom
    logging framework.
-   Project management: GitHub Issues + GitHub Projects + Pull Requests.
-   Git workflow: short-lived branch → PR → required CI → squash merge
    to protected `main`.
-   Design: neutral friendly surfaces, semantic colors, minimal local
    DesignSystem.
-   Replace the current Arteon/VW-derived app icon with a PitStop
    primary icon.
-   Max writes the first LinkedIn draft in English; language review
    follows.

## Complete file inventory

-   `01_PRODUCT_CHARTER.md`
-   `02_DOMAIN_MODEL.md`
-   `03_MAINTENANCE_ENGINE.md`
-   `04_AI_ARCHITECTURE.md`
-   `05_ENGINEERING_STANDARD.md`
-   `06_OBSERVABILITY.md`
-   `07_ANALYTICS.md`
-   `08_ROADMAP.md`
-   `09_INVESTIGATIONS.md`
-   `10_ADR_001_MAINTENANCE_ANCHORS.md`
-   `11_CURRENT_DOMAIN_AUDIT.md`
-   `12_LEARNING_LAB.md`
-   `13_TEST_STRATEGY.md`
-   `14_TELEMETRY_CONTRACT.md`
-   `15_RELEASE_AND_BETA.md`
-   `16_TASK_TEMPLATE.md`
-   `17_PRODUCT_DESIGN.md`
-   `18_NAMING_EXPLORATION.md`
-   `19_DEVELOPMENT_DIARY_AND_LINKEDIN.md`
-   `20_COMPETITIVE_RESEARCH.md`
-   `21_ANALYTICS_SERVICE_DECISION.md`
-   `22_LOGGING_DECISION.md`
-   `23_ENGINEERING_QUALITY_AND_CI.md`
-   `24_PROJECT_MANAGEMENT_AND_GITFLOW.md`
-   `25_MODULAR_ARCHITECTURE.md`
-   `26_DESIGN_SYSTEM.md`
-   `27_APP_ICON_STRATEGY.md`
-   `29_ANALYTICS_QUESTIONS.md`
-   `30_AI_PRODUCT_ANALYTICS.md`
-   `README.md`

## Decision ownership map

| Topic | Authoritative document |
| --- | --- |
| Analytics provider | `21_ANALYTICS_SERVICE_DECISION.md` |
| Product questions (`AQ-*`) | `29_ANALYTICS_QUESTIONS.md` |
| Event taxonomy and P0 ownership | `07_ANALYTICS.md` |
| Telemetry privacy and channels | `14_TELEMETRY_CONTRACT.md` |
| AI-assisted analytics workflow | `30_AI_PRODUCT_ANALYTICS.md` |
| AI runtime (Foundation Models) | `04_AI_ARCHITECTURE.md` |
| Logging | `22_LOGGING_DECISION.md` |
| Crash diagnostics | separate beta decision (Crashlytics) |
