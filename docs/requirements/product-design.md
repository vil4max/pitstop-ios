# Product Design Direction

**Status:** authoritative product design direction; iOS 27 redesign decisions of 2026-09-22 applied

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
- always on screen, the anchor point for talking to the app: the utility
  control on primary and detail screens, and the same bottom-trailing spot
  inside every other sheet, above the keyboard while typing;
- bottom-trailing;
- custom;
- visually distinct;
- not a floating `+`;
- not AI sparkle;
- not a tab.

## Pit visual identity

Decided by the owner on 2026-09-22 (design session; rationale in
[`../planning/ios27-redesign-proposal.md`](../planning/ios27-redesign-proposal.md)
§3.6b and §3.6d).

**Pit is a small companion head that lives behind the interface.**

- **Head:** a round head, pearl white with a soft top-left light and a
  hairline edge. It stays pearl white in dark mode: it is an object, not a
  surface. In the utility layer the whole 56 pt circle is Pit's head, with
  no glass disc behind it.
- **Face screen:** a deep navy visor, the same colour as the app icon's dark
  fill, set into the head by a thin grey bezel, with a gloss and a faint glow
  behind the eyes.
- **Eyes:** two lit lenses on the face screen. Each eye is a lens whose
  outline carries the state, and the two eyes tilt independently by a few
  degrees. The lenses are lit (soft blue-white, a small highlight and a
  halo, no pupils); during a knock they turn `accentPrimary` and the glow
  strengthens.
- **Acting:** the eyes carry every state of the motion language. The head
  adds only a tilt of up to 6° and a lift of up to 3 pt, and only in
  motion-language states; it never moves on its own.

Reference for mechanics only: lit eyes on a dark glass face and expression by
eye shape and tilt (the owner pointed at EVE from WALL-E). No character,
shape, colour or proportion is copied.

Avoid:
- a body, arms, mouth or hands;
- a cartoon mechanic, tools or a motorsport look;
- a mascot: oversized cute eyes, Pixar-like body language, idle sway;
- an inward "angry" eye angle: inward tilt is capped at 6° and means
  attention, never judgement;
- generic AI sparkle.

Pit's head is the utility control (the 56 pt circle) and appears in the Pit
capture sheet header (44 pt). The widget and the
control keep the capture glyph (ADR 0025). The app icon shows the same head
at rest (REQ-ICON-001, ADR 0037).

> Pit waits nearby.

See `pit-behavior-and-motion.md`.

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
Kestrel
```

```text
KESTREL
Notes
```

The large car photo belongs primarily on Car Board. Do not repeat the hero on every screen.

## Visual principle

> Neutral surfaces. One calm accent. Semantic maintenance colours only where state matters.

### Surface tiers

Every surface belongs to exactly one tier (owner decision 2026-09-22):

| Tier | Surfaces | Treatment |
|---|---|---|
| Stage | Car Hero, Road lane, Pit, the empty-state glyph disc | The only tinted, custom-drawn surfaces; `surfaceTint` is `accentPrimary` at 10–22 % (14–28 % in dark) |
| Grouped lists | Service, History, Notes, Road milestone list, every form | One inset-grouped container per section, rows separated by hairlines |
| Glass controls | Utility layer, toolbar actions, "Back to now", floating primary actions | Liquid Glass; glass is never applied to content |

Car Board tiles stay cards: a card is the entrance affordance.

### Status vocabulary

Status is a word, a glyph and a colour together, never colour alone. One
shape per state, shared by status chips, Road markers and widgets:

| State | Glyph | Colour |
|---|---|---|
| Ahead, up to date | ring | `accentPrimary`, `statusUpToDate` |
| Approaching | half-filled | `statusApproaching` |
| Due | filled | `statusDue` |
| Past due | filled with a ring | `statusDue` |
| Unknown, waiting for mileage | dashed ring | `contentSecondary` |

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

Fallback order (owner decision 2026-09-22):
1. the owner's photo, lifted onto the stage on device when possible,
   otherwise shown whole under the stage mask;
2. the neutral placeholder for the body the owner chose in the car editor,
   SUV by default or sedan: a side-view silhouette in flat system grey,
   facing right (the car drives toward the road ahead), with no make, model
   or detail. The body is never guessed from a name, a make or a locale.

No make- or model-aware imagery is planned. Never show a random unrelated
car as if it were the user's vehicle. The owner's photo stays on the device:
it is never committed, sent to analytics or placed in a widget timeline
entry.

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

## Requirements

Status `approved` here means decided by the owner in the design session.

### REQ-DESIGN-001 — Status is never colour alone
Status: approved (owner, 2026-09-22)
Core: P5
Source: [Status vocabulary](#status-vocabulary)
Given any maintenance or Road state shown to the user
When it is rendered
Then a word and a state glyph accompany the colour, and the glyph shape differs per state

### REQ-DESIGN-002 — Glass is reserved for floating controls
Status: approved (owner, 2026-09-22)
Core: P5
Source: [Surface tiers](#surface-tiers)
Given a primary or detail screen
When its surfaces are inspected
Then only the utility layer, toolbar actions and floating controls use Liquid Glass, and `just verify` fails when `glassEffect` appears outside the design system

### REQ-DESIGN-003 — One tint, one accent
Status: approved (owner, 2026-09-22)
Core: P5
Source: [Surface tiers](#surface-tiers)
Given the stage tier
When it is rendered
Then its tint is `accentPrimary` at a token-defined opacity, and no other surface is tinted

### REQ-DESIGN-005 — The car without a photo is the placeholder for the chosen body
Status: approved (owner, 2026-09-22)
Core: C2
Source: [Car image](#car-image)
Given no owner photo
When any surface shows the car
Then it shows the neutral placeholder for the body the owner chose, SUV when none was chosen, facing right, and never a make, model or body derived from other data
