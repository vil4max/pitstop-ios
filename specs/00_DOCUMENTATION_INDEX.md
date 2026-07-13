# PitStop Documentation Index

This folder is the authoritative working source of truth for PitStop.

## Start here

1. `../PROJECT_STATUS.md` (freeze status — read when resuming)
2. `README.md`
3. `01_PRODUCT_CHARTER.md`
4. `41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md`
5. `39_DOMAIN_INVENTORY.md`
6. `17_PRODUCT_DESIGN.md`
7. `31_CAR_BOARD_SCREEN_CONTRACT.md`
8. `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`
9. `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`
10. `34_CAPTURE_PIPELINE_SPEC.md`
11. `08_ROADMAP.md`
12. `38_WORK_PLAN.md`
13. `09_INVESTIGATIONS.md`

## Product, UX and IA

- `01_PRODUCT_CHARTER.md`
- `17_PRODUCT_DESIGN.md`
- `20_COMPETITIVE_RESEARCH.md`
- `26_DESIGN_SYSTEM.md`
- `27_APP_ICON_STRATEGY.md`
- `31_CAR_BOARD_SCREEN_CONTRACT.md`
- `32_ROAD_DOMAIN_AND_UI_CONTRACT.md`
- `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`
- `35_BOTTOM_UTILITY_LAYER_SPEC.md`
- `36_SCREEN_GRAMMAR_AND_DESIGN_SYSTEM.md`
- `41_PRODUCT_DECISIONS_AND_DESIGN_RATIONALE.md` — product why / rejected alternatives (not a behaviour contract)

## Domain

- `02_DOMAIN_MODEL.md`
- `03_MAINTENANCE_ENGINE.md`
- `10_ADR_001_MAINTENANCE_ANCHORS.md`
- `11_CURRENT_DOMAIN_AUDIT.md`
- `34_CAPTURE_PIPELINE_SPEC.md`
- `39_DOMAIN_INVENTORY.md`

## AI and learning laboratory

- `04_AI_ARCHITECTURE.md` — runtime AI architecture owner
- `12_LEARNING_LAB.md`
- `30_AI_PRODUCT_ANALYTICS.md` — AI Product Analyst workflow (not app runtime)
- `40_AI_ENGINEERING_ROADMAP.md` — deferred AI roadmap (not an implementation contract)

## Engineering, tests, observability and quality

- `05_ENGINEERING_STANDARD.md`
- `06_OBSERVABILITY.md`
- `13_TEST_STRATEGY.md`
- `14_TELEMETRY_CONTRACT.md`
- `22_LOGGING_DECISION.md`
- `23_ENGINEERING_QUALITY_AND_CI.md`
- `25_MODULAR_ARCHITECTURE.md`

## Analytics and beta

- `07_ANALYTICS.md`
- `15_RELEASE_AND_BETA.md`
- `21_ANALYTICS_SERVICE_DECISION.md`
- `29_ANALYTICS_QUESTIONS.md`
- `30_AI_PRODUCT_ANALYTICS.md`

## Planning and execution

- `08_ROADMAP.md`
- `38_WORK_PLAN.md`
- `09_INVESTIGATIONS.md`
- `16_TASK_TEMPLATE.md`
- `24_PROJECT_MANAGEMENT_AND_GITFLOW.md`

## Research and diary

- `18_NAMING_EXPLORATION.md`
- `19_DEVELOPMENT_DIARY_AND_LINKEDIN.md`
- `20_COMPETITIVE_RESEARCH.md`

## Product hierarchy

```text
PitStop
└── Car Board
    ├── Road
    ├── Notes
    ├── Service
    ├── History
    └── Car context

Persistent utility layer
├── Settings
└── Pit

Capture capability
└── Remember
    └── Capture Pipeline
```

## Documentation rule

Do not create a second specification for an already-owned concept without first deciding whether the existing owner should be extended. Avoid parallel source-of-truth documents.

The consolidated brainstorm was migration input, not a permanent competing specification. Its accepted decisions have been integrated into the authoritative documents in this folder.
