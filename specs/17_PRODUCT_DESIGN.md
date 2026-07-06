# Product Design Direction

**Status:** authoritative product design direction

## Design objective

PitStop should feel like a calm, modern journal for a car the driver cares about.

Target qualities:

```text
calm
clear
personal
modern
light
slightly playful
tactile
trustworthy
```

It must not feel like:
- a dealership portal;
- a diagnostic scanner;
- a fleet dashboard;
- a warning system;
- a motorsport product;
- a children's game;
- an AI chat wrapper.

## Root visual concept

> Home is the car. Everything else is a view into its memory.

The leading root IA is **Car Board**.

The car is visually primary. Supporting information is composed from product-defined summary tiles.

Tiles are **summary + entrance**, not navigation buttons.

Primary Car Board content:
- Car Hero;
- Road;
- Notes summary;
- Service summary;
- History summary;
- later, Expenses or other validated summaries.

## Layout direction

Initial target: portrait iPhone.

Two tile primitives only:

```text
.full
.half
```

V1:
- product-defined order;
- product-defined sizes;
- no resizing;
- no drag and drop.

V2 candidate:
- long press;
- haptic lift;
- drag;
- deterministic grid reflow;
- persisted order.

Do not build a generic dashboard framework.

## Persistent bottom utility layer

Current spatial direction:

```text
[ Settings ]                         [ Pit Eyes ]
```

This is not a tab bar.

The interaction reference is the spatial treatment of separate circular utility actions beside/around a lower content area, similar to the left/right separate controls in the provided messenger reference. This is a positional and mechanical reference only; do not visually copy another application.

Settings:
- one tap away;
- bottom-leading;
- visually clear;
- never hidden in overflow or only top-trailing.

Pit:
- always available on primary/detail screens;
- bottom-trailing;
- custom;
- visually distinct;
- not a floating `+`;
- not AI sparkle;
- not a tab.

## Pit visual hypothesis

**Pit Eyes / Behind the UI.**

The eyes are the character. Pit does not require a body.

Avoid:
- cartoon mechanic;
- robot;
- animated tool;
- mouth/hands;
- oversized cute mascot eyes;
- Pixar-like body language;
- generic AI sparkle.

Pit visually lives behind the interface and is expressed through gaze, eyelids, timing, and small movements.

> Pit waits nearby.

See `33_PIT_BEHAVIOR_AND_MOTION_SPEC.md`.

## Screen grammar

All primary and detail screens share:
- consistent navigation rhythm;
- top inset logic;
- content width;
- horizontal padding;
- section spacing;
- card geometry;
- vertical scrolling;
- bottom utility layer;
- stable Pit position.

Header pattern:

```text
eyebrow / context
large title
optional trailing action
```

Examples:

```text
MY CAR
Arteon
```

```text
ARTEON
Notes
```

The large car photo belongs primarily on Car Board. Do not repeat the hero on every screen.

## Visual principle

> Neutral surfaces. One calm accent. Semantic maintenance colours only where state matters.

Use semantic system-aware colours and design tokens.

Recommended character:

```text
Cloud Blue + Soft Gray + Warm Amber
```

This is not a fixed hex palette.

Red is reserved for destructive, error, or genuine danger states. Ordinary maintenance due state must not use danger semantics.

## Car image

The driver's relationship with the car is important. Car Hero is high-value.

Do not require a photo during first launch.

Fallback order:
1. user photo;
2. validated model-aware visual;
3. validated make-aware visual;
4. neutral abstract car visual.

Never show a random unrelated car as if it were the user's vehicle.

## Native Apple boundary

Default to native Apple components and interaction patterns:
- SwiftUI;
- NavigationStack;
- ScrollView;
- sheets;
- confirmation dialogs;
- menus where semantically appropriate;
- PhotosPicker;
- ContentUnavailableView;
- sensory feedback;
- system typography;
- semantic colours;
- SF Symbols.

Custom identity should concentrate in:
- Car Hero;
- Road;
- Pit Eyes;
- Pit Capture Surface;
- maintenance visualisation;
- Car Board summary tiles where native components are insufficient.

> If a standard Apple component solves the interaction, PitStop must justify replacing it.

## Accessibility

Support:
- Dynamic Type;
- VoiceOver;
- Reduce Motion;
- sufficient contrast;
- non-colour status meaning;
- minimum practical hit targets.

Pit's life must not depend on animation. Road meaning must not depend only on spatial animation.
