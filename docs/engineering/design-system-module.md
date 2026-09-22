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

``` text
PitStopColor.surfacePrimary
PitStopColor.surfaceSecondary
PitStopColor.surfaceElevated

PitStopColor.contentPrimary
PitStopColor.contentSecondary

PitStopColor.accentPrimary
PitStopColor.surfaceTint        (accent at a token-defined opacity; stage tier only)
PitStopColor.contentOnAccent

PitStopColor.statusPositive
PitStopColor.statusApproaching
PitStopColor.statusDue
PitStopColor.statusDanger
```

Backed by semantic asset colors with Light/Dark variants.

No generic runtime `Theme` protocol in P0.

## Typography

Prefer Dynamic Type/system fonts.

Roles:

``` text
display
title
headline
body
supporting
caption
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
StatusChip           word + state glyph + colour
RoadSign             milestone plate on a post, state glyph on the plate
RemainingShareTrack  share of the owner's own interval; drawn only with fresh facts
EmptyState           glyph disc, headline, one sentence, one or two actions
GlassPill            floating labelled glass control ("Back to now")
StepStrip            named steps of a multi-step sheet
PitHead              capsule head, face screen, lens eyes (poses per pit-behavior-and-motion.md)
ScreenHeader, TileCard, UtilityLayer (exist)
```

Typography roles map to SwiftUI text styles: display → largeTitle bold;
title → title3 semibold; headline → headline; body → body; supporting →
subheadline or footnote; caption → caption or caption2.

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

-   previews for Light/Dark and default and accessibility-extra-large text;
-   `just verify` fails on colour literals under `Features/` and on
    `glassEffect` outside `DesignSystem/` (REQ-DESIGN-002, REQ-DESIGN-004);
-   Dynamic Type preview matrix for critical components;
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
