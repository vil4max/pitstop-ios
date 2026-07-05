# Modular Architecture

**Status:** Proposed architecture baseline\
**Decision:** feature-oriented modular architecture with Clean
Architecture boundaries where they protect domain truth; MVVM +
Coordinator at presentation level.

## Short answer

MVVM + Coordinator is sufficient as a UI/presentation pattern.

It is **not** the whole application architecture.

Do not adopt a ceremonial Clean Architecture with five layers and
`UseCase` wrappers around every method.

Use:

``` text
Feature modules
+
pure Domain modules
+
small infrastructure adapters
+
MVVM presentation
+
Coordinator navigation
+
initializer DI
```

This is Clean-boundary thinking without Clean-Architecture boilerplate.

## Dependency rule

Dependencies point inward toward stable domain contracts.

``` text
App / Composition Root
        ↓
Feature UI modules
        ↓
Domain APIs / feature contracts
        ↑
Infrastructure adapters
```

Domain does not import: - SwiftUI; - SwiftData; - PostHog; - OSLog; -
Foundation Models; - Firebase; - UIKit.

## Proposed local package structure

``` text
PitStopApp/
    App/
    Composition/
    AppCoordinator/

Packages/
    PitStopDomain/
    MaintenanceDomain/
    NotesDomain/
    HistoryDomain/
    OdometerDomain/

    MaintenanceFeature/
    NotesFeature/
    HistoryFeature/
    OdometerFeature/
    TellPitStopFeature/
    SettingsFeature/

    DesignSystem/
    Persistence/
    FoundationModelsAdapter/
```

This is a **target direction**, not an implementation backlog.

## Package creation rule

> Package creation is demand-driven.

> No package without a real consumer boundary.

> A target architecture diagram is not an implementation backlog.

Extract a dedicated SPM package only when reuse or module dependency
boundaries justify it. A second package consumer is extraction pressure,
not an absolute mechanical requirement.

Do not create packages merely because they appear in a target diagram.

Possible future extractions when justified (not backlog items):

``` text
Analytics provider-neutral boundary + PostHog adapter
shared DEBUG logging facade
```

For `ANL-001`, the preferred first implementation hypothesis is the
smallest local boundary justified by the current repository —
conceptually similar to:

``` text
PitStopApp
└── Infrastructure
    └── Analytics
        ├── Analytics.swift
        ├── AnalyticsEvent.swift
        └── PostHogAnalytics.swift
```

This example is conceptual, not a mandatory folder structure or package
split. The implementation agent must inspect the repository before
selecting exact files or folders.

A dedicated Analytics + provider adapter package split is justified only
when a real module or package consumer requires it.

Do not split all packages in one migration PR.

## What belongs in app target

Only composition/platform shell:

``` text
@main app
dependency construction
root navigation/coordinator
scene lifecycle
global app routing
feature assembly
entitlements/configuration
```

The app target should become boring.

## What belongs in Domain

Pure business language and deterministic behavior.

Example `MaintenanceDomain`:

``` text
MaintenanceOperationID
MaintenancePolicy
MaintenanceCompletion
MaintenanceProgress
MaintenanceStatus
MaintenanceSnapshot
MaintenanceProcedure
ServicePlanner
SuggestedServiceScope
domain errors/validation
```

No persistence entity.

No ViewModel.

No analytics call.

A domain function may return facts that presentation/feature telemetry
observes.

## Feature module anatomy

Every feature module uses the minimum subset of these roles:

``` text
Feature API
Feature View
ViewModel
ViewState
ViewAction
Coordinator/Route contract if navigation exists
Feature-specific dependency protocols
Feature analytics protocol/event
Feature log event if needed
```

Not every screen requires every type.

## Screen construction standard

For a non-trivial screen:

### 1. View

Responsibilities: - render `ViewState`; - emit user intent as
`ViewAction`; - local ephemeral UI state only when truly visual.

Must not: - query SwiftData directly; - call PostHog; - calculate
maintenance status; - parse LLM output; - perform navigation decisions.

### 2. ViewState

A presentation model ready to render.

Example:

``` swift
struct MaintenanceStatusViewState: Equatable {
    let hero: StatusHeroViewState
    let sections: [MaintenanceSectionViewState]
    let isRefreshing: Bool
}
```

No SwiftData entity exposure.

### 3. ViewAction

User/system intent.

``` swift
enum MaintenanceStatusViewAction {
    case appeared
    case operationSelected(MaintenanceOperationID)
    case servicePlanSelected
}
```

Do not mirror every button into arbitrary closure properties if actions
form a coherent feature language.

### 4. ViewModel

Responsibilities: - orchestrate feature dependencies; - transform domain
output into ViewState; - handle ViewAction; - request navigation through
a narrow routing contract; - emit feature analytics.

Must not: - implement maintenance rules; - know PostHog event strings; -
access global singletons.

### 5. Mapper / Presenter

Create only when domain → ViewState transformation is substantial or
independently testable.

Do not create `FooMapper` for one string.

### 6. Coordinator

Owns navigation flow and feature assembly/navigation decisions.

Coordinator does not: - calculate domain status; - become a service
locator; - own feature business state.

Use child coordinators only for a real multi-screen flow.

### 7. Dependency protocol

Feature owns the protocol it needs.

Example:

``` swift
protocol MaintenanceStatusProviding: Sendable {
    func snapshot() async throws -> MaintenanceSnapshot
}
```

Infrastructure/domain adapter implements it.

Do not expose a giant `PitStopService`.

## Feature example

``` text
MaintenanceFeature
├── API/
│   ├── MaintenanceFeatureFactory.swift
│   └── MaintenanceRoute.swift
├── Status/
│   ├── MaintenanceStatusView.swift
│   ├── MaintenanceStatusViewModel.swift
│   ├── MaintenanceStatusViewState.swift
│   └── MaintenanceStatusViewAction.swift
├── Analytics/
│   ├── MaintenanceAnalytics.swift
│   └── MaintenanceAnalyticsEvent.swift
└── Logging/
    └── MaintenanceLogEvent.swift
```

If a folder contains one trivial file, flatten it. Structure follows
actual complexity.

## DI

Default: initializer injection.

``` swift
@MainActor
final class MaintenanceStatusViewModel {
    init(
        statusProvider: any MaintenanceStatusProviding,
        analytics: any MaintenanceAnalytics,
        router: any MaintenanceRouting
    )
}
```

The composition root wires live implementations.

Tests pass fakes/recorders.

Do not add a DI container until wiring pain is measured.

SwiftUI Environment is acceptable for presentation/system values and
design environment. It is not the default service locator for domain
services.

## Coordinator + SwiftUI

Use a pragmatic coordinator/router boundary.

Do not recreate UIKit coordinator ceremony if `NavigationStack`
path/state already solves a local flow.

Rule:

``` text
local feature navigation → feature route/state
cross-feature/root flow → AppCoordinator
```

## Module creation checklist

A new SPM module requires: - clear responsibility; - public API
statement; - dependency list; - reason it cannot remain in an existing
module; - tests; - owner of composition.

Failure: - package exists only to make architecture diagram impressive.

## Migration strategy

### Step 1

Extract pure `MaintenanceDomain`.

### Step 2

Validate analytics boundary for `ANL-001`.

Implement the smallest local boundary justified by the current
repository. See the `ANL-001` first-implementation hypothesis in the
package structure section above.

`ANL-001` validates:

``` text
analytics boundary
PostHog iOS integration
typed event mapping
privacy/configuration assumptions
```

It does **not** mandate creating separate Analytics and provider adapter
SPM packages. Package extraction is a separate consequence justified by
the actual dependency graph.

Decision after spike:

``` text
ADOPT
ADOPT WITH BOUNDARY
FALL BACK
```

### Step 3

Add minimal `DesignSystem`.

### Step 4

Build/refactor one new `MaintenanceFeature` using the screen standard.

### Step 5

Review friction before extracting more features.

Do not perform a big-bang modularization.

## PitStop iOS runtime vs AI Product Analyst workflow

``` text
PitStop iOS runtime
≠
AI Product Analyst development workflow
```

The iOS app architecture must not include:

-   MCP client;
-   AnalyticsAgent SPM package;
-   AIProductManager module;
-   runtime analytics agent loop;
-   autonomous product mutation from analytics.

PostHog MCP, if investigated later, belongs in the development
environment:

``` text
Cursor / AI engineering environment
→ analytics access
→ read evidence
→ draft investigation
```

Status: `INVESTIGATE` — see `30_AI_PRODUCT_ANALYTICS.md`

Product analytics evidence flow in development:

``` text
Product Question Registry (29_ANALYTICS_QUESTIONS.md)
→ typed events (07_ANALYTICS.md)
→ PostHog evidence layer (21_ANALYTICS_SERVICE_DECISION.md)
→ deterministic query
→ structured evidence
→ AI Product Analyst (manual / tool-assisted)
→ human decision
```

## Architecture success criteria

-   maintenance domain tests run without iOS UI/SwiftData/analytics;
-   feature ViewModels depend on narrow protocols;
-   app target is composition;
-   concrete analytics provider SDK import exists only in adapter
    boundary;
-   SwiftData entities do not leak into feature ViewState;
-   one feature can be tested with fake dependencies;
-   package graph has no cycles;
-   adding a screen does not require editing a global god service.

## Architecture failure criteria

-   every domain operation has a ceremonial `UseCase` type;
-   one protocol per concrete class without a test/boundary reason;
-   coordinator becomes dependency container;
-   generic repository hides useful domain semantics;
-   15 packages exist before two real features use the pattern;
-   `Core` becomes a miscellaneous dumping ground.

## Legacy/current behavior preservation rule

Module extraction is not permission to redesign existing behavior
silently.

Before extracting a feature/domain module:

``` text
inventory current behavior
→ characterize important existing cases
→ map old representation to target domain
→ add tests
→ extract/refactor
→ verify behavior
→ remove old representation
```

For Notes specifically, code-seeded examples such as film/wrap and
floor-mat reminders must be included in the first domain fixture set.
Their current representation is audited before migration.

Use strangler-style incremental replacement rather than a big-bang
rewrite.
