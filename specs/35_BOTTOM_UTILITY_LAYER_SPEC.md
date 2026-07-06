# Bottom Utility Layer Specification

**Status:** P0 UI contract

## Purpose

Provide persistent one-tap access to application Settings and Pit without a classical tab bar.

Current spatial model:

```text
[ Settings ]                         [ Pit Eyes ]
```

This is a utility layer, not root navigation.

## Settings

- bottom-leading;
- one tap away;
- stable position on primary/detail screens;
- system-recognisable settings semantics;
- not hidden in overflow;
- not only top-trailing;
- not a Car Board tile.

## Pit

- bottom-trailing;
- stable position;
- custom Pit Eyes affordance;
- opens Pit Capture Surface;
- not a tab;
- not a floating add button;
- not generic AI sparkle.

## Spatial reference

A reference pattern is separate circular left/right utility buttons flanking or living beside a lower content area. Use the mechanics of distinct utility actions with balanced visual weight.

Do not copy another application's exact shape, stroke, material, iconography, or dimensions.

## Safe areas and scrolling

The utility layer must:
- respect the bottom safe area;
- avoid hiding scroll content;
- remain reachable with one hand where practical;
- define keyboard behaviour;
- define sheet/full-screen-cover behaviour.

INVESTIGATE whether the layer is persistent above keyboard or yields to focused input.

## Accessibility

- clear VoiceOver labels;
- large hit targets;
- Dynamic Type must not cause overlap;
- Pit animation is not required to identify the control.

## Test-first scenarios

1. Settings reachable in one tap;
2. Pit reachable in one tap;
3. content is not obscured;
4. safe area respected;
5. large text does not overlap controls;
6. keyboard behaviour is deterministic;
7. detail screens preserve utility positions.

## Failure criteria

- layer behaves like a tab bar;
- Settings moves between screens;
- Pit becomes a `+`;
- controls obscure Road/tile content;
- implementation copies a reference application's visual treatment.
