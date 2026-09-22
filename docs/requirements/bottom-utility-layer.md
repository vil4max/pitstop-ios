# Bottom Utility Layer Specification

**Status:** P0 UI contract

Core: P5

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

Resolved (delivered behaviour): text input lives in sheets, so the layer
never rides up over the keyboard, and it is unchanged when the sheet closes.
The app has no full-screen covers; if one is added, it covers the layer too.
Pit's control is Pit's head: the whole 56 pt circle is the head (see
`product-design.md`, "Pit visual identity"), with no glass disc behind it;
Settings stays a glass circle with its glyph, and the two keep equal size.

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

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-UTILITY-001 — Utility layer is not a tab bar
Status: proposed
Core: P5
Source: [Purpose](#purpose), [Pit](#pit), [Failure criteria](#failure-criteria), [Pit availability](pit-behavior-and-motion.md#availability)
Given a primary or detail screen with the utility layer
When the user activates Settings or Pit
Then no tab selection state is shown and the layer does not act as root navigation

### REQ-UTILITY-002 — Settings is reachable in one tap
Status: proposed
Core: P5
Source: [Purpose](#purpose), [Settings](#settings), [Test-first scenarios](#test-first-scenarios)
Given any primary or detail screen
When the user taps the Settings control
Then Settings opens without passing through an overflow menu or a Car Board tile

### REQ-UTILITY-003 — Settings keeps a stable bottom-leading position
Status: proposed
Core: P5
Source: [Settings](#settings), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given the user moves between primary and detail screens
When each screen is displayed
Then the Settings control stays in the same bottom-leading position with system-recognisable settings semantics

### REQ-UTILITY-004 — Pit is reachable in one tap
Status: proposed
Core: P5
Source: [Purpose](#purpose), [Pit](#pit), [Test-first scenarios](#test-first-scenarios), [Pit availability](pit-behavior-and-motion.md#availability), [Pit test-first scenarios](pit-behavior-and-motion.md#test-first-scenarios)
Given any primary or detail screen, including when Pit is inactive and hides visual detail
When the user taps the Pit control
Then the Pit Capture Surface opens

### REQ-UTILITY-005 — Pit keeps a stable bottom-trailing position
Status: proposed
Core: P5
Source: [Pit](#pit), [Test-first scenarios](#test-first-scenarios), [Pit availability](pit-behavior-and-motion.md#availability)
Given the user moves between primary and detail screens
When each screen is displayed
Then the Pit control stays in the same bottom-trailing position

### REQ-UTILITY-006 — Pit is not an add button or AI sparkle
Status: proposed
Core: P5
Source: [Pit](#pit), [Failure criteria](#failure-criteria)
Given the Pit control is displayed
When its appearance and accessibility label are inspected
Then it uses the custom Pit Eyes affordance, not a `+` add button or a generic AI sparkle

### REQ-UTILITY-007 — Bottom safe area is respected
Status: proposed
Core: P5
Source: [Safe areas and scrolling](#safe-areas-and-scrolling), [Test-first scenarios](#test-first-scenarios)
Given a device with a bottom safe area inset
When the utility layer is displayed
Then the Settings and Pit controls lie within the safe area

### REQ-UTILITY-008 — Utility controls do not obscure content
Status: proposed
Core: P5
Source: [Safe areas and scrolling](#safe-areas-and-scrolling), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given a scrollable screen such as Road or Car Board tiles
When the user scrolls to the end of the content
Then no content is hidden behind the Settings or Pit controls

### REQ-UTILITY-009 — Utility controls have clear VoiceOver labels
Status: proposed
Core: P5
Source: [Accessibility](#accessibility), [Pit accessibility](pit-behavior-and-motion.md#accessibility)
Given VoiceOver is running
When focus moves to the Settings or Pit control
Then each control announces a clear action label

### REQ-UTILITY-010 — Large text does not cause overlap
Status: proposed
Core: P5
Source: [Accessibility](#accessibility), [Test-first scenarios](#test-first-scenarios)
Given the largest supported Dynamic Type size
When a primary or detail screen is displayed
Then the Settings and Pit controls do not overlap each other or screen content

### REQ-UTILITY-011 — Pit is identifiable without animation
Status: proposed
Core: P5
Source: [Accessibility](#accessibility), [Pit accessibility](pit-behavior-and-motion.md#accessibility)
Given Pit animation is not running, for example with Reduce Motion enabled
When the Pit control is displayed
Then the control remains visible, discoverable, and keeps its semantic label

### REQ-UTILITY-012 — Sheets cover the layer
Status: proposed (pending the simulator check at the medium detent, RD-010)
Core: P5
Source: [Safe areas and scrolling](#safe-areas-and-scrolling)
Given a sheet is presented
When the keyboard or the sheet is shown
Then the utility layer is neither visible above the sheet nor moved, and it is in its position when the sheet closes
