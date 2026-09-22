# App Icon

**Status:** Primary icon delivered (ICON-001, 2026-09-22) and redrawn as Pit's
head (ICON-002, 2026-09-22); requirements below are `proposed` except the
owner-decided concept\
**Decision records:** [`../decisions/0029-app-icon-pit-eyes.md`](../decisions/0029-app-icon-pit-eyes.md),
[`../decisions/0037-app-icon-pit-head.md`](../decisions/0037-app-icon-pit-head.md)

Core: P5

## Purpose

The owner sees the icon on the Home Screen and recognises PitStop at once.
The icon is the product's face outside the app, so it uses the same face as
inside the app: Pit's two eyes (ADR 0009, ADR 0028), and from the iOS 27
redesign Pit's round head with its face screen (owner decision 2026-09-22,
`product-design.md` "Pit visual identity").

## Current icon

- Source: one Icon Composer document, `Pitstop/AppIcon.icon`, picked up by the
  synchronized `Pitstop/` folder. The target's
  `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon`. There is no
  `AppIcon.appiconset`.
- Foreground (ICON-002, ADR 0037): Pit's round head at rest in four groups,
  back to front: the pearl head (Liquid Glass), the face (grey bezel and navy
  visor, flat), the lit lens eyes (Liquid Glass) and their white highlights
  (flat); all flat-filled vector layers.
- Background: an Icon Composer gradient fill, cloud blue in the default
  appearance and deep navy in the dark appearance.
- The system renders the clear and tinted appearances from the same document.
- The geometry is the resting pose of `pitHead()` in the redesign mockups
  (ADR 0037). The icon ships ahead of the redesign; RD-011 draws the in-app
  head from the same geometry. The shell's light and the eyes' shine come
  from Icon Composer; the mockup's halo and glow are not drawn.

## Constraints

- No text, wordmark, letter or tagline.
- No car silhouette, wrench, racing flag, speedometer, or any manufacturer
  mark, geometry or signature colour.
- No baked effects in the layer artwork: no shadows, blurs, glows, specular
  highlights, bevels or background gradients in the SVGs. Liquid Glass effects
  and the background come from Icon Composer.
- No pre-masked layers: the system applies the icon shape.

## Requirements

Status `proposed` means derived from the text above and awaiting owner
approval.

### REQ-ICON-001 — The icon is Pit's head
Status: approved (owner decision 2026-09-21; motif changed from the eyes alone to the head by owner decision 2026-09-22)
Core: P5
Source: [Purpose](#purpose), ADR 0029
Given the primary app icon
When it is shown in any appearance
Then its only foreground motif is Pit's round head with the face screen and the two eyes at rest, with no text, letter, body, mouth or hands

### REQ-ICON-002 — Eye geometry matches the in-app glyph
Status: proposed
Core: P5
Source: [Purpose](#purpose), ADR 0028
Given Pit's head at rest (ADR 0037 geometry; in the app from RD-011): the head, bezel and visor proportions and the lens outline, pose and highlight
When the icon layers are drawn
Then each layer is that geometry uniformly scaled, so the icon and the utility control show the same face

### REQ-ICON-003 — One app icon source
Status: proposed
Core: P5
Source: [Current icon](#current-icon)
Given the Pitstop target
When the app is built with the default Xcode used by CI
Then the only app icon source is `Pitstop/AppIcon.icon`, and the built `Assets.car` contains `AppIcon` renditions for the any, dark and tintable appearances

### REQ-ICON-004 — Every appearance is legible
Status: proposed
Core: P5
Source: [Current icon](#current-icon), ADR 0029 "Appearances"
Given the default, dark, clear light, clear dark, tinted light and tinted dark appearances
When the icon is rendered in each of them
Then the head reads against the background, both eyes read as separate shapes on the face screen, and the dark appearance uses its own dark fill rather than the default fill

### REQ-ICON-005 — Small sizes stay legible
Status: proposed
Core: P5
Source: [Constraints](#constraints)
Given the icon rendered at 40, 60 and 120 pixels in every appearance
When it is viewed on light and dark grounds
Then the head and the two eyes remain distinct, and neither the bezel nor the gloss is required to recognise them

### REQ-ICON-006 — No text, marks or baked effects
Status: proposed
Core: P5
Source: [Constraints](#constraints)
Given the layer artwork in `Pitstop/AppIcon.icon/Assets`
When it is inspected
Then it contains only filled vector shapes with no text, no manufacturer marks, no effects and no background

### REQ-ICON-007 — Colours come from the design system
Status: proposed
Core: P5
Source: ADR 0009, ADR 0029 "Design"
Given the icon's fill and layer colours
When they are compared with `PitColor`
Then the default fill ends on the light `accentPrimary` value, the head, visor and eyes use the colours of the in-app Pit head, and the visor matches the icon's dark fill

## Acceptance (ICON-001; ICON-002 repeated the `ictool` renders and the gate)

- Six appearances rendered with `ictool` (design generation 27) and inspected.
- 120, 60 and 40 px renders inspected on light and dark grounds.
- Built app: `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName` is
  `AppIcon`; `xcrun assetutil --info` lists `AppIcon` icon images for the any,
  dark and tintable appearances.
- Home Screen screenshot on the simulator.
- `just verify` passes with the default Xcode.

## Deferred

- **Alternate app icons** (for example Graphite and Warm, chosen in Settings).
  iOS supports them through `setAlternateIconName`; each alternate needs its
  own dark, clear and tinted variants. Not scheduled. If it ships, the
  analytics events are `app_icon_picker_opened` and `app_icon_changed` with
  `icon_variant` only, and no vehicle make in any event.
- **Vehicle-make icons.** Rejected: trademark use, implied manufacturer
  affiliation, an asset matrix per make, and the app's own identity disappears.
