# Design System Module

**Status:** Minimal design-system plan

## Decision

Create a local SPM `DesignSystem` module after the visual inventory.

It owns reusable visual language, not product/business semantics.

## Owns

``` text
semantic colors
typography roles
spacing scale
corner-radius tokens
selected reusable components
status visual presentation tokens
asset access required by shared components
```

## Does not own

``` text
MaintenanceStatus domain enum
Notes domain
navigation
analytics
networking
feature ViewModels
vehicle knowledge
```

A feature maps domain meaning to design-system presentation.

## Color API

Delivered as `PitColor` in `Shared/DesignSystem/PitColor.swift` (ADR 0038), compiled into the app and the widget extension:

``` text
PitColor.surfacePrimary
PitColor.surfaceSecondary
PitColor.surfaceElevated

PitColor.contentPrimary
PitColor.contentSecondary
PitColor.contentTertiary
PitColor.separator

PitColor.accentPrimary
PitColor.surfaceTint          (accent at DesignTokens.stageTint; stage tier only)
PitColor.surfaceTintStrong    (accent at DesignTokens.stageTintStrong; top of the stage gradient)
PitColor.contentOnAccent      (text and glyphs on an accentPrimary fill)

PitColor.statusUpToDate       (the delivered name for statusPositive)
PitColor.statusApproaching
PitColor.statusDue
PitColor.statusDanger
```

System roles come from UIKit semantic colours; custom roles are trait-resolved
light/dark values, and the tint also resolves Increase Contrast.

No generic runtime `Theme` protocol in P0.

## Typography

Prefer Dynamic Type/system fonts. Roles are `PitTypography` (ADR 0038):

``` text
display          largeTitle bold
title            title3 semibold
headline         headline
body             body
supporting       subheadline
supportingSmall  footnote
caption          caption
captionSmall     caption2
```

Do not hardcode a custom font before a brand decision.

## Spacing

Small intentional scale:

``` text
xs
s
m
l
xl
```

Do not create 30 spacing tokens.

## Components

Only extract after repeated use or explicit design-system value.

Components of the iOS 27 redesign (owner-approved 2026-09-22; cards RD-000,
RD-011, RD-012 in the work plan):

``` text
StageSurface         tinted stage for the Car Hero
CarVisual            owner photo (lifted) or the placeholder for the chosen body
StatusChip           word + state glyph (StatusGlyph) + colour
RoadSign             milestone plate on a post, state glyph on the plate
RemainingShareTrack  share of the owner's own interval; drawn only with fresh facts
EmptyState           glyph disc, headline, one sentence, one or two actions
GlassPill            floating labelled glass control ("Back to now")
StepStrip            named steps of a multi-step sheet
PitHead              round head, face screen, lens eyes (poses per pit-behavior-and-motion.md; RD-011)
ScreenHeader, TileCard, UtilityLayer (exist)
pitGlass(in:)        the only route to Liquid Glass for feature code
```

Delivered in RD-000: `StageSurface`, `StatusChip`, `EmptyState`,
`RemainingShareTrack`, `GlassPill`, `StepStrip`, `pitGlass(in:)`. `CarVisual`,
`RoadSign` and `PitHead` land with RD-012, RD-002 and RD-011.

Do not create a wrapper for every SwiftUI control.

## Themes/palettes

P0:

``` text
PitStop default semantic palette
system Light
system Dark
```

Future:

``` text
alternate accent palette
vehicle-inspired palette
```

Future palettes must preserve semantic status colors.

A blue car must not make `.statusDue` blue.

## Design-system tests

-   `#Preview` per component through `PreviewMatrix`: light, dark, default
    and accessibility-extra-large text;
-   `PitstopTests/DesignSystem/DesignRulesTests.swift` fails `just verify`
    on colour literals under `Features/` and on glass outside
    `DesignSystem/` (REQ-DESIGN-002, REQ-DESIGN-004); a test, because
    `Tooling/` belongs to the shared Runtime (ADR 0038);
-   colour-role tests for the stage tint and `contentOnAccent` contrast;
-   accessibility labels where component owns semantics;
-   snapshot testing only if a mature snapshot dependency is selected
    after research.

## Success

A feature uses semantic design roles and remains visually consistent
without importing a theme manager.

## Failure

The module becomes a generic UI framework or blocks normal SwiftUI
composition.

## Requirements

### REQ-DESIGN-004 — Features use roles, not literals
Status: approved (owner, 2026-09-22)
Core: P5
Source: [Color API](#color-api)
Given feature code
When `just verify` runs
Then it fails if a feature file contains a colour literal instead of a `PitColor` role
