#!/usr/bin/env bash
set -euo pipefail

REPO="vil4engineering/pitstop-ios"
PROJECT_OWNER="vil4max"
PROJECT_NUMBER="2"

create_issue() {
    local id="$1"
    local title="$2"
    local est="$3"
    local deps="$4"
    local labels="$5"
    local specs="$6"
    local slug="$7"
    local problem="$8"

    local body
    body="$(cat <<EOF
## Task ID
${id}

## Estimate
${est}

## Dependencies
${deps}

## Branch
\`${id}/${slug}\`

## Specs
${specs}

## Problem
${problem}

## Acceptance criteria
- [ ] Matches linked specs
- [ ] Tests first where applicable
- [ ] CI green on PR

## Issue template
See \`specs/16_TASK_TEMPLATE.md\`
EOF
)"

    local url
    url="$(gh issue create -R "$REPO" --title "${id} ${title}" --label "$labels" --body "$body")"
    gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$url" >/dev/null
    echo "${id}|${url##*/}|${slug}"
}

while IFS='|' read -r id title est deps labels specs slug problem; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    create_issue "$id" "$title" "$est" "$deps" "$labels" "$specs" "$slug" "$problem"
done <<'TASKS'
DOM-002|Spec-derived test fixtures|1d|DOM-001|domain,priority:P0,type:feature|specs/02_DOMAIN_MODEL.md, specs/34_CAPTURE_PIPELINE_SPEC.md|test-fixtures|Domain tests need stable fixtures derived from specs, not legacy seed data.
DOM-003|Capture domain types and confirmation policy tests|4d|DOM-001|domain,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|capture-domain|CaptureInput, MemoryProposal, confirmation policy, and domain commands need pure Swift types with tests first.
DOM-004|ADR-001 open questions closure|1d|—|domain,priority:P0,type:investigation|specs/10_ADR_001_MAINTENANCE_ANCHORS.md|adr-001-closure|Maintenance anchor decisions must be closed before Phase 7 maintenance work.
ENG-004|Persistence and provisional car context|3d|DOM-003, BOOT-001|ci,domain,priority:P0,type:quality|specs/31_CAR_BOARD_SCREEN_CONTRACT.md, specs/34_CAPTURE_PIPELINE_SPEC.md|persistence|SwiftData schema, migration safety, and provisional car persistence for first launch.
ENG-002|Analytics boundary|2d|CB-002|ci,priority:P2,type:quality|specs/21_ANALYTICS_SERVICE_DECISION.md, specs/07_ANALYTICS.md|analytics-boundary|Provider-neutral analytics facade before PostHog adapter.
ANL-001|Provider-neutral analytics spike|2d|ENG-002|ci,priority:P2,type:investigation|specs/29_ANALYTICS_QUESTIONS.md, specs/21_ANALYTICS_SERVICE_DECISION.md|analytics-spike|Validate PostHog adapter behind boundary after first UI events exist.
INV-ROAD-001|Road horizon and spacing|1d|—|investigation,priority:P0,type:investigation|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md, specs/09_INVESTIGATIONS.md|road-horizon|Decide initial Road horizon for sparse and dense milestone sets.
INV-ROAD-002|Road mixed time and mileage|1d|—|investigation,priority:P0,type:investigation|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md|road-mixed-anchors|Decide coexistence of date and mileage milestones without fake conversion.
INV-ROAD-003|Road milestone clustering|1d|INV-ROAD-001|investigation,priority:P0,type:investigation|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md|road-clustering|Decide when nearby milestones visually cluster.
INV-ROAD-004|Road return to current position|1d|INV-ROAD-001|investigation,priority:P0,type:investigation|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md|road-return-current|Decide native-feeling return-to-current mechanism for Road.
CB-001|Provisional car context|2d|ENG-004|ui,domain,priority:P0,type:feature|specs/31_CAR_BOARD_SCREEN_CONTRACT.md|provisional-car|Render usable Car Board state without setup funnel.
CB-002|Car Board shell and utility layer|4d|CB-001, ENG-003|ui,priority:P0,type:feature|specs/31, specs/35, specs/36|car-board-shell|Tile grid, screen grammar, Car Hero placeholder, Settings and Pit utility layer.
CB-003|Notes tile and entry|2d|CB-002, DOM-003|ui,domain,priority:P0,type:feature|specs/31_CAR_BOARD_SCREEN_CONTRACT.md|notes-tile|Notes summary tile and navigation entry.
CB-004|History tile and entry|2d|CB-002|ui,priority:P0,type:feature|specs/31_CAR_BOARD_SCREEN_CONTRACT.md|history-tile|History summary tile and navigation entry.
CB-005|Service tile summary|3d|CB-002|ui,priority:P0,type:feature|specs/31_CAR_BOARD_SCREEN_CONTRACT.md|service-tile|Deterministic maintenance summary on Car Board.
CB-006|Road projection domain and tests|4d|DOM-001, INV-ROAD-*|domain,priority:P0,type:feature|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md|road-projection|Pure Road projection logic with tests before UI.
CB-007|Road UI|4d|CB-006, INV-ROAD-*|ui,priority:P0,type:feature|specs/32_ROAD_DOMAIN_AND_UI_CONTRACT.md|road-ui|Road visualisation after investigations and projection tests.
CAP-001|CaptureInput boundary|2d|DOM-003|capture,domain,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|capture-input|Source-independent CaptureInput contract.
CAP-002|Proposal and confirmation without live model|3d|CAP-001|capture,domain,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|capture-policy|MemoryProposal and ConfirmationPolicy without Foundation Models.
CAP-003|Pit Eyes affordance|2d|CB-002|capture,ui,priority:P0,type:feature|specs/33_PIT_BEHAVIOR_AND_MOTION_SPEC.md, specs/35|pit-eyes|P persistent Pit control with minimal states.
CAP-004|Pit Capture Surface|3d|CAP-001, CAP-003|capture,ui,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md, specs/33|pit-capture-surface|One product-core capture path from Pit.
CAP-005|Foundation Models interpreter spike (RU)|5d|CAP-002|capture,priority:P0,type:investigation|specs/04_AI_ARCHITECTURE.md, specs/34_CAPTURE_PIPELINE_SPEC.md|interpreter-spike|Validate RU input against typed proposal schema.
CAP-006|Raw-preservation fallback|2d|CAP-002|capture,domain,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|raw-fallback|Unsupported or unavailable AI must not lose capture.
CAP-007|End-to-end Remember slice|4d|CAP-004–006, ENG-004|capture,priority:P0,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|remember-e2e|capture → proposal → policy → command → persistence → board update.
DISC-001|Question value registry|2d|M4|priority:P1,type:feature|specs/08_ROADMAP.md|question-registry|Every discovery question documents value unlocked and deferral path.
DISC-002|First high-value question|3d|DISC-001|priority:P1,type:feature|specs/08_ROADMAP.md|first-question|One question that measurably improves Service or Road.
DISC-003|Attention cooldown policy|2d|DISC-001|priority:P1,type:feature|specs/33_PIT_BEHAVIOR_AND_MOTION_SPEC.md|attention-cooldown|Test dismissal, deferral, and repeat suppression.
DISC-004|Pit semantic motion|3d|CAP-003|priority:P1,type:feature|specs/33_PIT_BEHAVIOR_AND_MOTION_SPEC.md|pit-motion|Motion states required by accepted Pit behaviour only.
SYS-001|App Intent investigation|1d|CAP-007|investigation,priority:P2,type:investigation|specs/34_CAPTURE_PIPELINE_SPEC.md, specs/09_INVESTIGATIONS.md|app-intent-inv|Investigate RememberInPitStopIntent constraints.
SYS-002|RememberInPitStopIntent|2d|SYS-001|capture,priority:P2,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|remember-intent|App Intent producing CaptureInput.
SYS-003|App Shortcut|1d|CAP-007|capture,priority:P2,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|app-shortcut|Shortcut into capture surface.
SYS-004|Widget investigation|1d|CAP-007|investigation,priority:P2,type:investigation|specs/09_INVESTIGATIONS.md|widget-inv|Fast-capture widget platform constraints.
SYS-005|Widget capture slice|3d|SYS-004|capture,priority:P2,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|widget-capture|Widget tap → capture surface.
SYS-006|Siri capture slice|3d|SYS-002|capture,priority:P2,type:feature|specs/34_CAPTURE_PIPELINE_SPEC.md|siri-capture|Siri path through Capture Pipeline.
MNT-INT-001|Maintenance intelligence investigations|5d+|M4|domain,priority:P2,type:investigation|specs/03_MAINTENANCE_ENGINE.md, specs/10_ADR_001_MAINTENANCE_ANCHORS.md|maintenance-intel|Manufacturer data, presets, and richer Road milestones after core product validation.
TASKS
