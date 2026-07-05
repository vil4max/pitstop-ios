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

Initial candidates:

``` text
StatusHero
SectionHeader
ContextShortcut
EmptyState
PrimaryAction
```

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

-   previews for Light/Dark;
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
