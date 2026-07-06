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
Arteon
```

```text
ARTEON
Notes
```

```text
ARTEON
Service
```

Do not invent a different header composition for every feature.

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
