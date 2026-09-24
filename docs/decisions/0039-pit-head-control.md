# Pit's Head as the Utility Control

**Status:** Accepted (owner decision 2026-09-22, proposal §3.6d "Decided": the round head, with the whole 56 pt
circle as Pit's head and no glass disc behind it; recorded with RD-011 on 2026-09-24)\
**Task:** RD-011\
**Amends:** [`0009-design-language.md`](0009-design-language.md) ("Two layers: calm content, glass controls" and
"Pit mark": the Pit control is no longer glass, and Pit is a head, not two capsule eyes)\
**Builds on:** [`0028-pit-eyes-and-motion.md`](0028-pit-eyes-and-motion.md) (motion language, timings, Reduce
Motion; unchanged; its drawing and the knock's bumps are amended here), [`0037-app-icon-pit-head.md`](0037-app-icon-pit-head.md) (head geometry),
[`0038-ios27-surface-tiers.md`](0038-ios27-surface-tiers.md) (glass through the design system only)\
**Contracts:** [`../requirements/product-design.md`](../requirements/product-design.md) "Pit visual identity",
[`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md) "Poses",
REQ-PIT-022, 023, 024

## Context

ADR 0009 put both utility controls on Liquid Glass and drew Pit as two capsule eyes on the glass. The owner then
chose a round companion head for Pit (2026-09-22): a pearl shell, a navy face screen in a thin bezel and two lit
lens eyes, with the whole 56 pt circle as the head. The app icon has shown that head since ICON-002 (ADR 0037),
while the app still drew the eyes in the glass circle. The Poses table and REQ-PIT-022…024 fix how the head acts.

## Decision

- **No glass for Pit.** `PitUtilityButton` draws `PitHead` at 56 pt in the utility layer and inside every other
  sheet, and the capture sheet header draws it at 44 pt (`DesignTokens.pitHeaderHeadSize`). Settings keeps its
  interactive glass circle; Pit's head is an object, not a floating material. Size, 20 pt inset, label, hint,
  the "Has a question" value on a knock and the identifier are unchanged.
- **Touch feedback.** Glass gave the circle a scale and a highlight on touch. `PitHeadButtonStyle` keeps both:
  the head shrinks to 92 % and a navy tint (`PitColor.headPressed`) darkens it while pressed, without a spring
  under Reduce Motion. A disabled Pit (a sheet saving, REQ-PIT-026) is dimmed to 45 %, as the plain button
  style dimmed the glass control.
- **Geometry.** `PitHeadGeometry` holds ADR 0037's numbers in the 56-unit view box, plus the mockup's shell light,
  glosses, glow and closed-eye arc, which the icon leaves to Icon Composer. The icon is not regenerated: the head
  uses its geometry unchanged.
- **Colours.** Every colour of the head is a `PitColor` role (`headShell…`, `headBezel`, `headVisorTop/Bottom`,
  `headGlow`, `headEye`, `headShadow`, `headPressed`) with light, dark and high-contrast values. The head stays
  pearl with a navy screen in dark mode. A light shadow lifts it off light content.
- **Reduce Transparency and Increase Contrast.** Both drop the see-through decoration: the two glosses, the glow and
  the eye halos (`PitHeadFinish`). The shell, bezel, screen and lenses are opaque fills; the hairline, the eye
  highlight and the shadow stay slightly translucent, because they carry the edge, the lens shine and the
  separation from content, and they show nothing of the content behind the head. Increase Contrast also darkens the
  shell's edge, the bezel and the screen's top, whitens the eyes and thickens the hairline.
- **Poses as values.** `PitPose` is what the head draws for one `PitState`: per-eye outline, turn and scale, the
  eye offset, the eye tint and glow, and the head's tilt and lift. The values follow the Poses table; where the
  mockup drew a different number the approved table wins (blink 20 % not 18 %, listening 6 % taller not 8 %,
  knock lift 3 pt not 2 pt), and the mockup's state strip has no glance, so the glance follows the table's words.
- **Inward tilt.** `PitPose.inwardTilt` is half the angle between the two eyes, positive when their tops
  converge. REQ-PIT-022 caps it at 6°, reached only by the knock. A roll of both eyes the same way (thinking,
  10°; glance, 8°) leaves it unchanged, so it cannot read as the "\ /" angle of judgement; each eye's own turn
  stays within the 10° of proposal §3.6b.
- **Knock colour.** Only the knock pose lights the eyes in `accentPrimary` and strengthens the glow (REQ-PIT-023).
  The eyes resolve their colours in a dark colour-scheme environment, because the screen is navy in both
  appearances: `accentPrimary` is then the pale accent, where the light accent would sink into the navy. Against
  the bare screen the pale accent is about 7:1 (`PitKnockColourTests`), and that is what Increase Contrast draws,
  since it removes the glow (about 8:1 measured on a render). With the knock's full-strength glow, as the mockup
  draws it (`#7DBAFA` eyes on a `#6FB2FF` glow), a render measures about 1.3:1 between the eyes, 2.4:1 at their
  outer edges and 3.3:1 below them: the knock reads by the colour change, the inward tilt and the lift, not by eye
  contrast. Lowering the knock glow is left to the owner (the Poses table asks for a stronger glow).
- **Head motion.** Only thinking (tilt 6° aside), startle (lift 2 pt) and knock (lift 3 pt, lean in 4°) move the
  head (REQ-PIT-024); every idle action keeps it still, and bounded life (ADR 0028) scales and shifts the eyes,
  never the head. The knock's two bumps are 1.5 pt dips from the lifted pose, so the head stays between rest and
  3 pt; before, the eyes' bumps rose 2.5 pt above a 3 pt lift. Lift and tilt are in head units, points at 56 pt,
  and scale with the 44 pt header. With Reduce Motion every pose is shown without animation and the knock plays
  no dips (`PitHeadMotion`).
- **Removed.** `PitEyesGlyph`, `PitEyeGeometry` and `PitEyeShape`. The life plan and animation timings of ADR 0028
  are unchanged in `PitEyeLife.swift`, and ADR 0028's vocabulary tests check `PitPose` with the same meaning.

## Verified

- Tests: `PitHeadTests` (ADR 0037 geometry, nesting, a rendered shell, screen and eyes at 56 and 44 pt, colour
  roles, Reduce Transparency and Increase Contrast finishes), `PitControlTests` (no glass on the Pit control,
  accessibility unchanged, the header head, press feedback), `PitPoseTests` (REQ-PIT-022), `PitKnockColourTests`
  (REQ-PIT-023, including a rendered knock eye; it fails when the dark environment is removed),
  `PitHeadMotionTests` (REQ-PIT-024), ADR 0028's `PitEyeGeometryTests`, `PitPresenceTests` and
  `PitCaptureEyesTests`.
- Simulator, iOS 27.0: the Car Board in light and dark, with Increase Contrast, and at the largest accessibility
  text size with the stage under the layer. Every pose, the sheet header at the default and the largest text
  size, the head over tiles, text and the stage, the Reduce Transparency finish and the disabled control were
  rendered with `ImageRenderer`.
- Not checked on the simulator: Reduce Transparency (no `simctl` switch), the pressed state, Pit inside a feature
  sheet and the capture sheet header (they need taps), and motion timing on a device.

## Rejected alternatives

- **The head on a glass disc.** The owner decided the whole circle is the head; a disc behind it would make two
  round shapes and spend glass on an object.
- **Keep interactive glass as the head's material.** Glass would refract the content behind the pearl shell and
  tint it, so the head would not stay pearl in dark mode.
- **The light accent on the knock.** About 2:1 on the navy screen: the knock would look like the eyes going dark.
- **Per-eye inward tilt as the REQ-PIT-022 measure.** It would forbid the approved thinking pose (both eyes rolled
  10°), which is a roll, not a converging angle.
- **Regenerating the icon from the mockup's shading.** ADR 0037 rejects baked shading; the head reuses the icon's
  geometry, so no icon change is needed.

## Consequences

- The utility layer now mixes one glass control (Settings) and one object (Pit). REQ-UTILITY-001 still holds: no
  selection, no tab bar.
- The head, not the eyes, is Pit's mark in the app; the widget and the control keep the capture glyph (ADR 0025).
- A future change to `PitHeadGeometry` changes the face the icon shows and must regenerate the icon (ADR 0037).
