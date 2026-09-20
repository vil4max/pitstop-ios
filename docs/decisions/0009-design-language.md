# Design Language and Car Board Shell

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-20: "design it yourself, modern, for Swift 6 and iOS 27"); owner review
pending\
**Task:** CB-002\
**Contracts:** [`../requirements/product-design.md`](../requirements/product-design.md),
[`../requirements/screen-grammar.md`](../requirements/screen-grammar.md),
[`../requirements/bottom-utility-layer.md`](../requirements/bottom-utility-layer.md),
[`../requirements/car-board-screen.md`](../requirements/car-board-screen.md)

## Decision

### Two layers: calm content, glass controls

Content (hero, tiles, lists) sits on opaque grouped-background surfaces with a
26 pt continuous corner radius and a hairline border. Only the utility layer
uses Liquid Glass (`glassEffect(.regular.interactive(), in: .circle)` inside a
`GlassEffectContainer`). Glass is the platform's language for controls that
float above content; using it for tiles would make summaries harder to read and
would spend the one distinctive material on everything.

### Colour

`PitColor` names the roles from the screen grammar. Surfaces and text map to
system grouped-background and label colours, so dark mode and Increase
Contrast come from the system for those roles. The custom accent and status
pairs have no high-contrast variant yet; the light accent was chosen for at
least 4.5:1 on the primary surface because it colours small text. The accent is a cloud blue; maintenance
attention is amber, with `statusDue` a deeper amber. Red exists only as
`statusDanger`. Values live in one file as light/dark pairs. Asset-catalog
colours were not used because a pair in code is reviewable in a diff and the
roles have no designer-owned source yet.

### Car Hero

The catalog image `DefaultVehicleHero` is a specific production car. Showing
it for a car the user has not identified would break "never show a random
unrelated car as if it were the user's vehicle", so the provisional hero is
`AbstractCarView`, a neutral drawn silhouette, marked decorative for
VoiceOver. The asset stays for a later model-aware visual. While the car is
provisional the hero offers one action, "Name your car", instead of a setup
checklist.

### Tiles

`CarBoardTileDescriptor.v1` fixes kind, size, and order; `rows(_:)` turns it
into the contract composition (Road / Notes + Service / History + empty future
slot). It is a list, not a layout engine. Two half tiles in a row share one
height. At accessibility text sizes half tiles become full-width rows in the
same order, because half width cannot hold large text (REQ-BOARD-025).

Until CB-003…007 land, each tile shows its true sparse state in words ("No
service facts yet, so nothing is due") and opens a destination that says the
surface is still being built. No counts, rings, or urgency are drawn from
absent data.

### Utility layer

`RootView` owns the `NavigationStack` and attaches the layer with
`safeAreaInset(edge: .bottom)` outside it. One instance therefore keeps the
same position on Car Board and on every pushed screen, and scroll content is
inset by the layer's height so the last tile always scrolls clear. The buttons
have no selected state and open sheets, so the layer cannot read as a tab bar.

Keyboard behaviour (open question in the contract): text input happens in
sheets, which cover the layer; the root ignores the keyboard safe area so the
layer never rides up over content.

### Pit mark

Two capsule eyes with a highlight, drawn in code, with the label "Pit". It is
static: Pit must be identifiable without animation. Motion is CAP-003 and
DISC-004.

## Rejected alternatives

- **Glass tiles.** Lower text contrast over a plain background, and no content
  behind them to refract.
- **Tab bar or toolbar for Settings and Pit.** The contract forbids a tab bar,
  and a toolbar would move between screens.
- **An overlay instead of a safe-area inset.** It needs hand-tuned bottom
  padding on every screen and still covers content at rest.
- **The production-car image as the default hero.** See above.
- **A separate `DesignSystem` Swift package now.** The module guide makes
  package creation demand-driven; one app target is the only consumer.

## Verified

Simulator, iOS 27, iPhone 17: light and dark appearance, default and
`accessibility-large` text (not the largest AX5 size), first-launch board, and a pushed detail screen
with the layer in place. Not verified: VoiceOver reading order on device,
Reduce Transparency, right-to-left layout, and the ru/uk strings on screen.
