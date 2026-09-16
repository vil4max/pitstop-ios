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
See \`docs/tasks/template.md\`
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
DOM-002|Spec-derived test fixtures|1d|DOM-001|domain,priority:P0,type:feature|docs/requirements/domain-model.md, docs/requirements/capture-pipeline.md|test-fixtures|Domain tests need stable fixtures derived from specs, not legacy seed data.
DOM-003|Capture domain types and confirmation policy tests|4d|DOM-001|domain,priority:P0,type:feature|docs/requirements/capture-pipeline.md|capture-domain|CaptureInput, MemoryProposal, confirmation policy, and domain commands need pure Swift types with tests first.
DOM-004|ADR-001 open questions closure|1d|—|domain,priority:P0,type:investigation|docs/decisions/0001-maintenance-anchors.md|adr-001-closure|Maintenance anchor decisions must be closed before Phase 7 maintenance work.
ENG-004|Persistence and provisional car context|3d|DOM-003, BOOT-001|ci,domain,priority:P0,type:quality|docs/requirements/car-board-screen.md, docs/requirements/capture-pipeline.md|persistence|SwiftData schema, migration safety, and provisional car persistence for first launch.
ENG-002|Analytics boundary|2d|CB-002|ci,priority:P2,type:quality|docs/decisions/0002-analytics-service.md, docs/operations/analytics.md|analytics-boundary|Provider-neutral analytics facade before PostHog adapter.
ANL-001|Provider-neutral analytics spike|2d|ENG-002|ci,priority:P2,type:investigation|docs/operations/analytics-questions.md, docs/decisions/0002-analytics-service.md|analytics-spike|Validate PostHog adapter behind boundary after first UI events exist.
INV-ROAD-001|Road horizon and spacing|1d|—|investigation,priority:P0,type:investigation|docs/requirements/road-domain-and-ui.md, docs/planning/investigations.md|road-horizon|Decide initial Road horizon for sparse and dense milestone sets.
INV-ROAD-002|Road mixed time and mileage|1d|—|investigation,priority:P0,type:investigation|docs/requirements/road-domain-and-ui.md|road-mixed-anchors|Decide coexistence of date and mileage milestones without fake conversion.
INV-ROAD-003|Road milestone clustering|1d|INV-ROAD-001|investigation,priority:P0,type:investigation|docs/requirements/road-domain-and-ui.md|road-clustering|Decide when nearby milestones visually cluster.
INV-ROAD-004|Road return to current position|1d|INV-ROAD-001|investigation,priority:P0,type:investigation|docs/requirements/road-domain-and-ui.md|road-return-current|Decide native-feeling return-to-current mechanism for Road.
CB-001|Provisional car context|2d|ENG-004|ui,domain,priority:P0,type:feature|docs/requirements/car-board-screen.md|provisional-car|Render usable Car Board state without setup funnel.
CB-002|Car Board shell and utility layer|4d|CB-001, ENG-003|ui,priority:P0,type:feature|docs/requirements/car-board-screen.md, docs/requirements/bottom-utility-layer.md, docs/requirements/screen-grammar.md|car-board-shell|Tile grid, screen grammar, Car Hero placeholder, Settings and Pit utility layer.
CB-003|Notes tile and entry|2d|CB-002, DOM-003|ui,domain,priority:P0,type:feature|docs/requirements/car-board-screen.md|notes-tile|Notes summary tile and navigation entry.
CB-004|History tile and entry|2d|CB-002|ui,priority:P0,type:feature|docs/requirements/car-board-screen.md|history-tile|History summary tile and navigation entry.
CB-005|Service tile summary|3d|CB-002|ui,priority:P0,type:feature|docs/requirements/car-board-screen.md|service-tile|Deterministic maintenance summary on Car Board.
CB-006|Road projection domain and tests|4d|DOM-001, INV-ROAD-*|domain,priority:P0,type:feature|docs/requirements/road-domain-and-ui.md|road-projection|Pure Road projection logic with tests before UI.
CB-007|Road UI|4d|CB-006, INV-ROAD-*|ui,priority:P0,type:feature|docs/requirements/road-domain-and-ui.md|road-ui|Road visualisation after investigations and projection tests.
CAP-001|CaptureInput boundary|2d|DOM-003|capture,domain,priority:P0,type:feature|docs/requirements/capture-pipeline.md|capture-input|Source-independent CaptureInput contract.
CAP-002|Proposal and confirmation without live model|3d|CAP-001|capture,domain,priority:P0,type:feature|docs/requirements/capture-pipeline.md|capture-policy|MemoryProposal and ConfirmationPolicy without Foundation Models.
CAP-003|Pit Eyes affordance|2d|CB-002|capture,ui,priority:P0,type:feature|docs/requirements/pit-behavior-and-motion.md, docs/requirements/bottom-utility-layer.md|pit-eyes|P persistent Pit control with minimal states.
CAP-004|Pit Capture Surface|3d|CAP-001, CAP-003|capture,ui,priority:P0,type:feature|docs/requirements/capture-pipeline.md, docs/requirements/pit-behavior-and-motion.md|pit-capture-surface|One product-core capture path from Pit.
CAP-005|Foundation Models interpreter spike (RU)|5d|CAP-002|capture,priority:P0,type:investigation|docs/engineering/ai-architecture.md, docs/requirements/capture-pipeline.md|interpreter-spike|Validate RU input against typed proposal schema.
CAP-006|Raw-preservation fallback|2d|CAP-002|capture,domain,priority:P0,type:feature|docs/requirements/capture-pipeline.md|raw-fallback|Unsupported or unavailable AI must not lose capture.
CAP-007|End-to-end Remember slice|4d|CAP-004–006, ENG-004|capture,priority:P0,type:feature|docs/requirements/capture-pipeline.md|remember-e2e|capture → proposal → policy → command → persistence → board update.
DISC-001|Question value registry|2d|M4|priority:P1,type:feature|docs/planning/roadmap.md|question-registry|Every discovery question documents value unlocked and deferral path.
DISC-002|First high-value question|3d|DISC-001|priority:P1,type:feature|docs/planning/roadmap.md|first-question|One question that measurably improves Service or Road.
DISC-003|Attention cooldown policy|2d|DISC-001|priority:P1,type:feature|docs/requirements/pit-behavior-and-motion.md|attention-cooldown|Test dismissal, deferral, and repeat suppression.
DISC-004|Pit semantic motion|3d|CAP-003|priority:P1,type:feature|docs/requirements/pit-behavior-and-motion.md|pit-motion|Motion states required by accepted Pit behaviour only.
SYS-001|App Intent investigation|1d|CAP-007|investigation,priority:P2,type:investigation|docs/requirements/capture-pipeline.md, docs/planning/investigations.md|app-intent-inv|Investigate RememberInPitStopIntent constraints.
SYS-002|RememberInPitStopIntent|2d|SYS-001|capture,priority:P2,type:feature|docs/requirements/capture-pipeline.md|remember-intent|App Intent producing CaptureInput.
SYS-003|App Shortcut|1d|CAP-007|capture,priority:P2,type:feature|docs/requirements/capture-pipeline.md|app-shortcut|Shortcut into capture surface.
SYS-004|Widget investigation|1d|CAP-007|investigation,priority:P2,type:investigation|docs/planning/investigations.md|widget-inv|Fast-capture widget platform constraints.
SYS-005|Widget capture slice|3d|SYS-004|capture,priority:P2,type:feature|docs/requirements/capture-pipeline.md|widget-capture|Widget tap → capture surface.
SYS-006|Siri capture slice|3d|SYS-002|capture,priority:P2,type:feature|docs/requirements/capture-pipeline.md|siri-capture|Siri path through Capture Pipeline.
MNT-INT-001|Maintenance intelligence investigations|5d+|M4|domain,priority:P2,type:investigation|docs/requirements/maintenance-engine.md, docs/decisions/0001-maintenance-anchors.md|maintenance-intel|Manufacturer data, presets, and richer Road milestones after core product validation.
TASKS
