# iOS 27 Visual Refresh: Surface Tiers

**Status:** Accepted (owner approved the redesign proposal 2026-09-22; recorded with RD-000 on 2026-09-23)\
**Task:** RD-000\
**Builds on:** [`0009-design-language.md`](0009-design-language.md) (calm content, glass controls; this ADR
supersedes nothing there), [`../planning/ios27-redesign-proposal.md`](../planning/ios27-redesign-proposal.md) §1, §3.8, §3.10, §6\
**Contracts:** REQ-DESIGN-001…004 ([`../requirements/product-design.md`](../requirements/product-design.md),
[`../engineering/design-system-module.md`](../engineering/design-system-module.md))

## Context

Every row on Service, History, Notes and Road was its own 26 pt card, so a list of facts weighed as much as
the car itself, and status was carried by coloured text alone. The approved redesign sorts every surface
into three tiers and gives status one shape vocabulary. RD-000 builds the shared pieces before any screen
changes; each screen card then adopts them.

## Decision

- **Three tiers.**
  - *Stage*: the Car Hero, the Road lane, Pit's eyes and the empty-state glyph disc. Only this tier is tinted:
    `PitColor.surfaceTint` / `surfaceTintStrong`, which are `accentPrimary` at token opacities (10 % and 22 % in
    light, 14 % and 28 % in dark; `DesignTokens.stageTint`, `stageTintStrong`). `StageSurface` draws it.
  - *Grouped lists*: detail screens put records of one kind in one inset-grouped container (REQ-GRAMMAR-001);
    Car Board tiles stay cards because a card is the entrance affordance.
  - *Glass controls*: the utility layer, toolbar actions, "Back to now" and a sheet's primary action. Feature
    code reaches glass only through `pitGlass(in:)` and `GlassPill`, never `glassEffect` directly.
- **Status glyph vocabulary** (`StatusGlyph`): ring = ahead or up to date, half = approaching, filled = due,
  filled with a halo = past due, dashed = unknown or waiting for mileage. `StatusChip` is word + glyph +
  colour; the word carries the meaning for VoiceOver. Road and Service map their states to glyphs in their
  presentation files; a Road milestone waiting for mileage is dashed although the projector files it as
  `.upcoming`; today's `systemImage` values stay until each screen card replaces them. Red is never a
  maintenance state.
- **Remaining-share track**: the used share of the owner's own interval, clamped to 0…1 and hidden from
  VoiceOver, which reads the fact line. It is not a health score: it says how much of an interval the owner
  set has gone by, nothing about the car's condition. RD-003 decides when it is drawn.
- **`contentOnAccent`**: white on the light accent, a deep navy (0.04, 0.13, 0.27) on the pale dark-mode
  accent. The mockups show white in both; white on `#7DBAFA` is about 2:1, below even the 3:1 large-text
  minimum, so dark mode deviates. A test keeps both at 4.5:1 or more.
- **Typography roles** (`PitTypography`): display, title, headline, body, supporting, supportingSmall, caption,
  captionSmall, mapped to Dynamic Type text styles; no custom font.
- **Reduce Transparency and Increase Contrast**: under either setting `pitGlass` becomes an opaque
  `surfaceSecondary` shape with a hairline; `StageSurface` gets an opaque base and a hairline; Increase Contrast raises both tint steps.
- **Enforcement**: `PitstopTests/DesignSystem/DesignRulesTests.swift` runs inside `just verify` and fails on a
  colour literal under `Features/` (REQ-DESIGN-004) and on glass outside `DesignSystem/` (REQ-DESIGN-002).
  `Color.clear` is allowed: it is layout, not colour.
- **Previews**: every component RD-000 adds has a `#Preview` in `PreviewMatrix` (light, dark, each at the
  default size and at accessibility extra large). This is the first use of previews in the app.

## Alternatives rejected

- **Glass tiles**: glass on content competes with the floating controls and breaks REQ-DESIGN-002.
- **A tab bar**: the utility layer stays two controls without selection (REQ-UTILITY-001).
- **A custom font**: no brand decision; Dynamic Type text styles scale for free.
- **Colour-only status**: fails users who cannot tell amber from green and fails REQ-DESIGN-001.
- **A single estimated date on Road**: the estimate stays a range with its prefix (ROAD-EST-002).
- **A SwiftLint custom rule for the literal check**: `Tooling/.swiftlint.yml` is owned by the shared Runtime,
  and `baseline.py` fails `just verify` when it drifts from the template. A test in the app's own target needs
  no Runtime change and still fails the gate.

## Consequences

- Screen cards RD-001…RD-012 adopt these components; a screen that still uses `FeatureEmptyState` or a
  `systemImage` status icon is not yet redesigned, not wrong.
- The Track several step marker and selected quick pick now use `PitColor.accentPrimary` instead of
  `Color.accentColor` (the PREP-006 leftover), which could resolve to the navy `AccentColor` asset instead of
  the role.
- The widget target does not compile `DesignSystem/`; RD-009 moves what the widget needs into `Shared/`.
