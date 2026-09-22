# Screen Grammar and Design System

**Status:** P0 UI consistency contract

## Goal

PitStop screens must feel like one application. Custom product identity is concentrated in a small set of product surfaces; ordinary interaction remains Apple-native.

## Shared grammar

Primary/detail screens share:
- top inset rhythm;
- content width;
- horizontal padding;
- section spacing;
- card geometry;
- vertical scrolling behaviour;
- persistent bottom utility layer;
- stable Pit position.

## Header

Pattern:

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

```text
KESTREL
Service
```

Do not invent a different header composition for every feature.

Trailing actions live in the navigation toolbar as glass buttons; related
actions form one toolbar menu. On detail screens a 28 pt round avatar of the
car (photo or placeholder) may precede the eyebrow; the large hero stays on
Car Board.

The large car hero belongs primarily to Car Board.

## Navigation

Use native NavigationStack semantics unless a product requirement proves insufficient.

Do not create:
- custom back gestures;
- hidden navigation zones;
- feature-specific tab bars;
- inconsistent modal conventions.

## Surfaces

Use semantic tokens defined by the design system.

Conceptual roles:

```text
surfacePrimary
surfaceSecondary
surfaceElevated

contentPrimary
contentSecondary
contentTertiary

accentPrimary

statusUpToDate
statusApproaching
statusDue
statusDanger

separator
```

Do not spread direct RGB literals or arbitrary `Color.blue` usage through feature code.

## Product-specific custom surfaces

Custom UI is justified primarily for:
- Car Hero;
- Road;
- Pit Eyes;
- Pit Capture Surface;
- maintenance visualisation;
- Car Board summary tiles where native components are insufficient.

Ordinary controls should prefer Apple-native components.

## Motion

Motion must communicate:
- state transition;
- focus;
- spatial relationship;
- Pit semantic behaviour.

Avoid decorative continuous animation.

Respect Reduce Motion.

## Haptics

Use haptics for meaningful interaction moments:
- confirmed capture;
- tile/action lift in future drag mode;
- important selection transitions;
- bounded Pit interaction.

Do not add haptics to every tap.

## List geometry

Repeated records of one kind are rows in one inset-grouped container per
section, with hairline separators and no separator after the last row. A
26 pt card is reserved for entrances (Car Board tiles) and the stage tier.
Fields inside forms use an 18 pt radius; nested radii are concentric.

## Dynamic Type reflow

- Half tiles become full-width rows at accessibility sizes, in the same order.
- Chips wrap instead of scrolling horizontally.
- Row actions move under the text.
- Horizontally scrolling lanes grow in height and never clip labels.
- Only the utility circles, Pit's head and toolbar glyphs keep a fixed size.
- Every control keeps a 44 pt target.

## Empty and sparse states

Unknown data is expected.

Do not use:
- `n/a` dashboards;
- fake zero metrics presented as facts;
- large blank cards;
- setup forms embedded into Home.

A sparse state should communicate:
1. what is known;
2. what the surface is for;
3. one useful next action when appropriate.

Composition: a tinted glyph disc, a headline, one sentence and at most two
actions, placed in the top third of the content.

## Accessibility

Required:
- Dynamic Type;
- VoiceOver;
- Reduce Motion;
- semantic labels;
- non-colour status meaning;
- sufficient contrast;
- practical touch targets.

## Review checklist

Before accepting a new screen:
- does it use the shared header grammar?
- does it use standard navigation?
- does it preserve utility layer behaviour?
- are semantic tokens used?
- is custom UI justified?
- is sparse state intentional?
- does it work with Reduce Motion?
- does VoiceOver expose the primary meaning?

## Requirements

### REQ-GRAMMAR-001 — Rows live in grouped containers
Status: approved (owner, 2026-09-22)
Core: P5
Source: [List geometry](#list-geometry)
Given a screen section listing records of one kind
When it renders
Then the records are rows in one grouped container, not one card per record

### REQ-GRAMMAR-002 — Header and toolbar grammar
Status: approved (owner, 2026-09-22)
Core: P5
Source: [Header](#header)
Given a detail screen
When it renders
Then it shows eyebrow and large title, and its actions in the navigation toolbar as glass buttons or one menu

### REQ-GRAMMAR-003 — Text never clips at accessibility sizes
Status: approved (owner, 2026-09-22); verified manually on the simulator after each redesign card (no snapshot tests)
Core: P5
Source: [Dynamic Type reflow](#dynamic-type-reflow)
Given the largest Dynamic Type size
When any primary or detail screen renders
Then no text is truncated below its meaning, chips wrap, and every control keeps a 44 pt target

### REQ-GRAMMAR-004 — Sparse state composition
Status: approved (owner, 2026-09-22)
Core: P5, C2
Source: [Empty and sparse states](#empty-and-sparse-states)
Given an owned surface with no records
When it renders
Then it shows a glyph, a headline, at most one sentence and at most two actions, and no placeholder metric
