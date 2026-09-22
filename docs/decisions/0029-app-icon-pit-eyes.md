# App Icon: Pit's Eyes in Liquid Glass

**Status:** Accepted (owner decision 2026-09-21); motif, layers and groups
amended by [ADR 0037](0037-app-icon-pit-head.md) (Pit's head, 2026-09-22)\
**Task:** ICON-001\
**Builds on:** [`0009-design-language.md`](0009-design-language.md) (colour roles, Pit mark),
[`0028-pit-eyes-and-motion.md`](0028-pit-eyes-and-motion.md) (eye geometry)\
**Contracts:** [`../requirements/app-icon.md`](../requirements/app-icon.md)
(REQ-ICON-001…007)

## Context

The shipped icon was an asset-catalog `AppIcon.appiconset`: a flat "P" with a
wordmark and tagline, an opaque dark variant, and a stray macOS 512@2x copy of
the light image. It carried text, had no layers, and so could not take part in
the iOS 27 Liquid Glass rendering; the clear and tinted appearances were
generated from a flat bitmap.

Apple's current guidance:

- [Human Interface Guidelines, App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
  (change log entry of June 8, 2026, "Refined guidance for Liquid Glass"):
  iOS icons are layered; the system applies specular highlights, refraction,
  translucency and shadows, so artwork should not bake them in; embrace
  simplicity with a minimal number of shapes; include text only when
  essential; keep core features the same across the default, dark, clear and
  tinted appearances; colour backgrounds generally give the greatest contrast
  in dark icons; provide square, unmasked layers.
- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer):
  one `.icon` file represents the app icon everywhere and replaces an existing
  icon asset catalog; export layers as SVG on a 1024 x 1024 canvas without
  background, shadows or effects; name layers with numbers from back to front;
  set the background as a solid or gradient fill and appearance variants in
  Icon Composer; at most four groups.

The owner chose the concept "Pit's eyes" over a "P" monogram on 2026-09-21.

## Decision

### One Icon Composer document

`Pitstop/AppIcon.icon` is the only app icon source. `AppIcon.appiconset` is
removed. The synchronized `Pitstop/` folder adds the document to the target,
and `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` names it; no project setting
changed. Xcode 27.0 (the CI default) compiles it with `actool` into
`Assets.car` (icon stack, groups and vector layers per appearance) plus the
`AppIcon60x60@2x.png` fallback files.

### Design

- **Motif:** Pit's two eyes in the resting state, nothing else.
- **Geometry:** derived from `PitEyeShape` and `PitEyesGlyph` (ADR 0028), not
  redrawn. The resting openness (0.92) gives the capsule with a slightly
  flattened upper lid; eyes are 9 x 15 pt with 5 pt spacing. The glyph is
  scaled uniformly by 26 (1 pt = 26 px) and the visible eyes, not the 15 pt
  frame, are centred on the 1024 canvas: the pair spans x 212–812 and
  y 333–691, about 59% of the width, inside the grid's safe area.
- **Highlight:** the glyph's main highlight (3.4 pt circle, offset +1.4, -2.6
  pt from the eye centre) at the same scale. The faint lower highlight is
  omitted: at 60 px and below it becomes noise and adds nothing to
  recognition.
- **Colours (ADR 0009):** the eyes are white, as `contentPrimary` is in dark
  mode; the highlight is the light `accentPrimary` (#1A5EB3), the colour of
  the surface behind the eyes, as the in-app highlight uses the surface
  colour. The default fill is a gradient from a lighter cloud blue
  (0.29, 0.56, 0.89) to the light `accentPrimary`. The dark fill is a deep
  navy gradient (0.09, 0.16, 0.29 to 0.03, 0.06, 0.13) derived from the same
  hue. These two fill-only colours are icon-local; they are not new
  `PitColor` roles.
- **Groups (back to front):** `1-eyes` with Liquid Glass on the layer,
  specular on, neutral shadow at 0.5, translucency 0.15; `2-highlights` without
  glass, specular or shadow, so it reads as a flat mark on the glass eye.
  Translucency is low because at 0.3 the eyes lose contrast in tinted dark.
- **No warm accent.** A second accent colour was optional and made the mark
  busier; two shapes are enough.

### Appearances

| Appearance | Background | Eyes |
|---|---|---|
| Default | Cloud-blue gradient fill | White glass, blue highlight |
| Dark | Navy gradient from the dark fill specialization | White glass, blue highlight |
| Clear light / clear dark | System material | System-rendered monochrome |
| Tinted light / tinted dark | System tint | System-rendered in the tint colour |

The dark fill must be written as a `fill-specializations` array whose first
entry has no `appearance` (the default) and whose second has
`"appearance" : "dark"`. With a top-level `fill` plus a dark specialization,
`ictool` ignores the specialization and renders the system's dark background
with blue-tinted eyes; this was checked by rendering a red dark fill both ways.

### Editing

Open `Pitstop/AppIcon.icon` in Icon Composer (Xcode > Open Developer Tool >
Icon Composer, or "Open with Icon Composer" under the preview in Xcode). Fill
and appearance variants are under the icon file's Style inspector; glass,
specular, shadow and translucency are per group. To change a shape, replace
the SVG in `Assets/` with the same file name; keep the 1024 x 1024 canvas,
filled shapes only, no background. A shape change starts from `PitEyeShape`
so the icon and the in-app glyph stay the same face (REQ-ICON-002).

Headless preview of every appearance:

```sh
ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ictool" Pitstop/AppIcon.icon --export-image --output-file out.png \
  --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1 \
  --design-generation 27
```

Renditions: `Default`, `Dark`, `ClearLight`, `ClearDark`, `TintedLight`,
`TintedDark`.

### Launch screen

The launch storyboard no longer shows the old "P" artwork (`pitstop-launch.png`,
now deleted) on a navy field. It is a plain view whose background is the
system colour `systemGroupedBackground`, the same colour as `surfacePrimary`
behind Car Board, so it follows light and dark mode without an asset. It
carries no image, no text and no constraints.

[Human Interface Guidelines, Launching](https://developer.apple.com/design/human-interface-guidelines/launching)
says the launch screen is not a branding opportunity: make it nearly identical
to the first screen, show only a solid colour if the app starts with one, avoid
text, match the appearance mode, and include logos only when they are a fixed
part of the first screen. Pit's eyes are on Car Board, but only as the small
animated glyph inside the Liquid Glass button of the utility layer; a static
storyboard cannot draw that glass control, so any eyes mark would look
different from the first frame and flash. The brand match with the icon is
carried by the icon itself and by the glyph once the app is running.

Rejected: a centred eyes mark on the background colour (a splash logo the HIG
advises against, and a jump when Car Board replaces it); an eyes imageset at
the utility-layer position (without the glass circle it does not match the
first frame, and its position depends on the device's safe-area insets);
a launch colour asset (it would duplicate a system colour that is
already dynamic).

## Verified

- `ictool` renders of all six appearances, and 120, 60 and 40 px downscales on
  light and dark grounds: both eyes are distinct in every appearance. Tinted
  dark has the lowest contrast (system tint on near-black), as for system
  icons.
- Build with Xcode 27.0 (27A266a): `CFBundleIconName = AppIcon`;
  `xcrun assetutil --info` lists `AppIcon` icon images for
  `UIAppearanceAny`, `UIAppearanceDark` and `ISAppearanceTintable`, and the
  `1-eyes` and `2-highlights` icon groups.
- Simulator Home Screen (iPhone 17, iOS 27) in the light icon style. The
  simulator's Home Screen icon style did not follow `simctl ui appearance
  dark`, and it could not be switched headlessly, so the dark, clear and
  tinted appearances on a Home Screen are checked only through `ictool`.
- Launch screen on the iPhone 17 simulator (iOS 27), fresh install, light and
  dark: the launch frame is a solid #F2F2F7 in light and #000000 in dark, the
  same pixels as Car Board's background in its first frame, with no flash.

## Rejected alternatives

- **Keep `AppIcon.appiconset`.** Flat bitmaps get no Liquid Glass layering,
  and Apple's documentation makes the `.icon` file replace the asset catalog
  icon; keeping both would leave two sources named `AppIcon`. The deployment
  target is iOS 27, so no older-release fallback artwork is needed.
- **"P" monogram.** A letter says less than Pit's face, repeats the idea of
  the icon being replaced, and letter marks are advised only when essential.
  Owner decision 2026-09-21.
- **Dark eyes on a light background** (the in-app light-mode colours). A light
  background turns grey-on-grey in the clear appearances, and white foreground
  shapes on a colour field are what the system glass and tint rendering are
  built for.
- **Letting the system generate the dark background.** It rendered a near-black
  background and tinted the eyes blue, which loses the white eyes that make
  the face.
- **Two groups merged into one.** Renders were identical; separate groups keep
  the highlight's settings independent when tuning in Icon Composer.

## Open

- Fine glass tuning (specular placement, shadow, refraction) by eye in Icon
  Composer and on a device.
- Dark, clear and tinted Home Screen check on a device.
