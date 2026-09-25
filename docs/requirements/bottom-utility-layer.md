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

### About

Settings ends with an About section: the version and build, one line saying
who makes PitStop and how, and a row that opens the public source code. The
line names the developer as "vil4max" and calls AI coding agents tools, not
authors; it names no AI product. Because the same binary could go to the App
Store, the text never says "lab", "experiment", "beta", "demo" or
"AI-powered", and never suggests that the user's data feeds an AI process
(App Review Guidelines 2.1(a), 2.2, 5.1.2). The link goes only to
`github.com/vil4max/pitstop-ios`, which is public. English wording (owner,
2026-09-25): "Pitstop is an independent app by vil4max, built with AI coding
agents and reviewed and released by its developer. The source code is open
on GitHub." Russian and Ukrainian follow the same meaning.

## Pit

- bottom-trailing;
- stable position;
- always on screen (owner rule 2026-09-22): when a sheet covers the layer,
  Pit alone stays at the same bottom-trailing spot inside the sheet, above
  the keyboard while typing; Settings is not repeated in sheets, which have
  their own Close or Cancel;
- Pit's round head (see `product-design.md`);
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

Resolved (delivered behaviour): text input lives in sheets; the layer itself
never rides up over the keyboard and is unchanged when the sheet closes,
while Pit stays on screen inside the sheet (see Pit).
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

### REQ-UTILITY-012 — Sheets keep Pit and cover the rest of the layer
Status: approved (owner rule 2026-09-22: Pit is always on screen; status line updated by the owner, 2026-09-24); RD-010 saw only the Pit Capture Surface on the simulator (inset at the medium detent, large at AX-XXXL); Pit inside a feature sheet or Settings is not yet checked on screen and is tracked as DEV-PIT-SHEET
Core: P5
Source: [Pit](#pit), [Safe areas and scrolling](#safe-areas-and-scrolling)
Given a sheet other than the Pit Capture Surface is presented
When the sheet or the keyboard is shown
Then Pit stays visible at the bottom-trailing spot of the sheet, above the keyboard, Settings is not shown over the sheet, and both return to their layer positions when the sheet closes

### REQ-UTILITY-013 — About says who makes PitStop and links the source
Status: proposed (owner chose the wording, the name and the order on 2026-09-25; lands after SYS-008)
Core: P5
Source: [About](#about)
Given Settings is open
When the About section is shown
Then it shows the version and build, the line "Pitstop is an independent app by vil4max, built with AI coding agents and reviewed and released by its developer. The source code is open on GitHub." in the user's language (en, ru, uk), and a "Source code on GitHub" row that opens github.com/vil4max/pitstop-ios, and no text in it says lab, experiment, beta, demo or AI-powered
