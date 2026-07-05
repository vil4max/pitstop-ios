# Product Design Direction

**Status:** Product design baseline\
**Decision:** move away from Volkswagen-brand visual language as the
primary PitStop identity.

## Design objective

PitStop should feel like a calm, friendly personal car companion.

It should not feel like: - a Volkswagen application; - a dealership
portal; - a diagnostic scanner; - a dark automotive dashboard; - a
warning system; - a motorsport product.

Target qualities:

``` text
calm
friendly
clear
light
personal
modern
slightly playful
trustworthy
```

## Visual principle

> Neutral surfaces. One calm accent. Semantic maintenance colors only
> where state matters.

The current heavy Volkswagen blue/dark direction should be treated as an
experiment, not the product identity.

## P0 palette direction

Recommended starting direction:

``` text
Surface / canvas
warm or cool near-white / system background

Secondary surface
soft neutral gray

Primary accent
soft clear blue

Text
system semantic label colors

Success
system green / tuned semantic token

Approaching
warm amber

Due
soft orange

Danger
red — reserved for real destructive/error/danger states
```

Do not use red for normal maintenance due state.

Do not use a saturated brand blue as a large full-screen background.

## Candidate visual character

Working direction:

``` text
Cloud Blue + Soft Gray + Warm Amber
```

This is a character description, not a fixed hex palette.

Example token roles:

``` swift
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

The implementation should use semantic design tokens rather than
`Color.blue`, Volkswagen hex values, or direct RGB literals throughout
views.

## Dynamic color without overengineering

P0: - support system Light and Dark appearances; - define semantic color
assets/tokens with light/dark variants; - use system semantic colors for
text/background where possible; - define only the minimum custom PitStop
tokens.

Do not build: - user-selectable themes; - per-vehicle themes; - dynamic
palette generation from car photo; - remote theme configuration; - a
general design-system framework.

Future experiment: - optional vehicle/personality accent; -
photo-derived accent; - seasonal or context accents.

These require a product reason and an investigation.

## Dark mode

Dark mode remains supported because it is a system appearance.

It is not the primary brand direction.

The dark palette should feel like the same calm product in a low-light
environment, not a black automotive cockpit.

Avoid: - pure black as a branding decision; - neon blue; - excessive
glowing borders; - dashboard/gauge visual metaphors.

## Status hero

The one-glance status should use:

``` text
icon
short state
one supporting fact
```

Examples:

``` text
✓
All caught up
Next service in about 3,200 km
```

``` text
!
Service approaching
Engine oil in about 900 km
```

``` text
●
Time to service
Engine oil service is due
```

Color is reinforcement, not the only information channel.

Required: - icon/shape; - text; - accessible contrast; - VoiceOver
meaning.

## Card design

Prefer: - generous whitespace; - moderate corner radius; - low visual
noise; - clear hierarchy; - restrained material usage; - one primary
action per card where possible.

Avoid: - every section as a bordered card; - heavy shadows; - automotive
carbon/metal textures; - gradients without semantic purpose; - dense
status chips.

## Typography

Use the system typography and Dynamic Type.

The product voice should be plain and concise.

Prefer:

``` text
Service approaching
Engine oil in about 900 km
```

Avoid:

``` text
CRITICAL MAINTENANCE ALERT
ENGINE LUBRICATION SERVICE THRESHOLD 88% EXCEEDED
```

## Vehicle image

The driver may have emotional attachment to the car. A personal photo
can be a high-value personalization surface.

P0: - deliberate neutral vehicle placeholder; - photo optional; - no
photo required during onboarding.

P1: - PhotosPicker; - crop/position; - image downsampling/storage
review.

Exact model image catalog: - INVESTIGATE licensing, exact-generation
matching and source quality.

A wrong car image is a product failure.

## Design validation tasks

### DSGN-001 Current UI visual inventory

Capture every current screen and classify: - Volkswagen-specific
color; - fixed color; - semantic system color; - status color; -
decorative color.

Success: - inventory exists; - no redesign yet.

### DSGN-002 Introduce minimal semantic color tokens

Tests: - snapshot/UI validation where practical; - contrast/manual
accessibility checklist.

Success: - core screens no longer depend directly on VW brand colors; -
light/dark variants exist; - token count remains small.

Failure: - generic theme engine is introduced.

### DSGN-003 Status hero visual spike

Create 3 visual variants: 1. icon-led; 2. soft tinted status surface; 3.
neutral surface with status accent.

Test with five-second comprehension review.

Success: - viewer can state status and next concern without explanation.

### DSGN-004 Friendly home hierarchy

Goal: - car identity/personal photo; - one-glance status; - next
service; - contextual notes.

Failure: - home becomes an analytics dashboard.

## Design success criteria

-   5-second status comprehension: 5/5 internal/beta checks.
-   No maintenance meaning relies on color alone.
-   Dynamic Type does not break critical status hierarchy.
-   Light and Dark appearances both pass the release visual checklist.
-   User can identify PitStop screenshots without Volkswagen branding.
-   Beta interviews do not describe the app primarily as "dark",
    "technical", or "dealer-like".

## Design failure criteria

-   the UI looks like a generic automotive dashboard;
-   dark mode dictates the brand;
-   blue is used everywhere because the current car is Volkswagen;
-   semantic status colors become decorative accents;
-   a theme architecture is built before a second real theme exists.
