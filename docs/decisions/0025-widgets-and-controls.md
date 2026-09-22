# Widgets and Controls: Open Pit from the System

**Status:** Accepted for implementation (owner decisions 2026-09-21)\
**Task:** SYS-005 ("Widget capture slice")\
**Investigation:** [`../planning/investigations/sys-004-widgets.md`](../planning/investigations/sys-004-widgets.md)\
**Contracts:** [`../core.md`](../core.md) (C4),
[`../requirements/capture-pipeline.md`](../requirements/capture-pipeline.md)
(REQ-CAPTURE-002, REQ-CAPTURE-023),
[`0005-toolchain-and-project-format.md`](0005-toolchain-and-project-format.md),
[`0023-remember-intent.md`](0023-remember-intent.md),
[`0024-app-shortcuts.md`](0024-app-shortcuts.md)

## Context

REQ-CAPTURE-023 asks that a tap on the Home Screen widget opens the capture
surface without routing through Car Board. ADR 0024 already routes an
outside request into the Pit sheet: `OpenPitIntent` records a request on
`CaptureSurfaceRequests`, and `RootView` takes it over the current surface,
deferring while a feature editor is presented. SYS-004 found that WidgetKit
offers two documented ways to reach that routing:

- A **control** (`ControlWidget`, Control Center, Lock Screen, Action button)
  can open the app only through an action that adopts `OpenIntent` and is a
  member of both the app and the widget extension targets. A plain foreground
  intent on a control runs in the extension in the background.
- A **widget** that only opens the app should use `widgetURL(_:)` or `Link`,
  not an intent button (Apple reserves widget buttons for actions that do more
  than open the app). The app receives the URL in `onOpenURL`.

Both need a widget extension, which the project did not have.

## Decision

### Owner decisions (2026-09-21)

1. **Surfaces:** an "Open Pit" control (Control Center, Lock Screen, Action
   button) and a data-free widget in two families, `systemSmall` (Home
   Screen) and `accessoryCircular` (Lock Screen). Both open the Pit sheet.
2. **Bundle ID** of the extension: `dev.vil4max.pitstop.widgets`.
3. **URL scheme** `pitstop://`, which can only open the Pit sheet
   (`pitstop://pit`); it is routed through `onOpenURL` into
   `CaptureSurfaceRequests`.
4. **`OpenPitIntent` adopts `OpenIntent`** if the SYS-003 App Shortcut keeps
   working, otherwise a hidden control-only intent is added. Outcome:
   **adopted**. The shortcut provider still lists Open Pit second, the built
   App Intents metadata shows the `OpenEntity` system protocol and one
   `target` parameter with the default `pit`, so neither Siri nor the control
   asks for it; no second intent exists.
5. **No data, no App Group now.** A widget with car data is a separate task
   (SYS-007 proposal in the work plan).

### Shape

| Piece | Where | Behavior |
|---|---|---|
| `CaptureSurface` | `Shared/CaptureSurface.swift` | One-case `AppEnum` (`pit`): the `OpenIntent` target, the widget's URL (`pitstop://pit`), and the only URL the app accepts |
| `OpenPitIntent` | `Shared/OpenPitIntent.swift` (moved from `Pitstop/App/Intents/`) | `OpenIntent` with `target: CaptureSurface = .pit`; unchanged `.foreground(.immediate)`, `allowedExecutionTargets = .main`, `.requiresLocalDeviceAuthentication`; `perform()` calls `CaptureSurfaceRequests.request()` |
| `CaptureSurfaceRequests` | `Shared/CaptureSurfaceRequests.swift` (moved from `Pitstop/App/`) | Adds `request(opening:)`: requests Pit for Pit's URL, returns false and does nothing for any other URL |
| URL entry | `PitstopApp` (`onOpenURL` on the scene root), `Config/Info.plist` (`CFBundleURLTypes`, scheme `pitstop`) | Pit's URL becomes the same pending request as Open Pit, so ADR 0024's deferral and single opening apply unchanged; other URLs are logged as ignored without their content |
| `OpenPitControl` | `PitstopWidgets/OpenPitControl.swift` | `StaticControlConfiguration` with `ControlWidgetButton(action: OpenPitIntent())` |
| `CaptureWidget` | `PitstopWidgets/CaptureWidget.swift` | `StaticConfiguration`, one static timeline entry with policy `.never`; the view shows the capture glyph (`square.and.pencil`, as the Open Pit shortcut) and "Remember", not the app icon; `widgetURL(CaptureSurface.pit.url)` |

`onOpenURL` sits on the scene root rather than inside `RootView`: in DEBUG
`RootView` first shows a preparation placeholder, and a URL delivered on a
cold launch before its content appears would otherwise have no handler. The
request waits until `RootView` takes it, as a cold-launch Open Pit does.

`CaptureSurface(url:)` accepts `pitstop://pit` with an optional trailing
slash, scheme and host in any case, and rejects any path, query, fragment,
user, password, or port. The scheme is public: any app or web page can open
it, and all it can do is open the Pit sheet, over an unlocked phone and
whatever screen the person was on.

`allowedExecutionTargets = .main` keeps `perform()` in the app although the
extension compiles the intent; `@Dependency` resolves only in the app, which
registers `CaptureSurfaceRequests` in `PitstopApp.init`.

### Project structure

- New target `PitstopWidgets` (`"product-type": "app-extension"`, id
  `A10000000000000000000403`), product `PitstopWidgets.appex`, written into
  the JSON `project.xcproj` by hand after the OneCart shape (same Runtime,
  ships a WidgetKit extension from a JSON project): the app target lists it in
  `dependencies` and has an `Embed App Extensions` copy phase
  (`plugins-directory`); the product reference is a member of that phase.
- Settings mirror the app: `MARKETING_VERSION` 1.1.0 and
  `CURRENT_PROJECT_VERSION` 1 (so `project_versions.py` and `tf-check` see
  one marketing version and `ci_scripts/ci_post_clone.sh` rewrites the build
  number of both targets), development team from the project level,
  `IPHONEOS_DEPLOYMENT_TARGET` 27.0, `SWIFT_VERSION` 6.0 with approachable
  concurrency, iPhone only, development region ru, display name PitStop,
  `SKIP_INSTALL`. No entitlements.
- `GENERATE_INFOPLIST_FILE = YES` with `PitstopWidgets/Info.plist` holding
  only `NSExtensionPointIdentifier` `com.apple.widgetkit-extension` (the
  Xcode template's split); the plist is excluded from the synchronized folder.
- Two synchronized folders: `PitstopWidgets/` (extension only) and `Shared/`
  (`target-membership` of both `Pitstop` and `PitstopWidgets`). Nothing else
  from `Pitstop/` enters the extension.
- The Runtime needs no change: the shared `Pitstop` scheme builds the
  extension as an implicit dependency, `run-sim` still picks `Pitstop.app`,
  and `bundle_id_for_scheme` reads the application product.

### Localization

The intent's strings must resolve in each bundle whose App Intents metadata
names them. They moved from `Localizable.xcstrings` into a shared table,
`Shared/OpenPit.xcstrings`, compiled into both bundles, and the code names the
table (`LocalizedStringResource(_:table:)`). The built metadata records
`"table": "OpenPit"` for the title, description, parameter, and enum. The
widget and control names live in the extension's own
`PitstopWidgets/Localizable.xcstrings` (en, ru, uk), reusing the wording of
the Open Pit title and description and of `shortcut.remember.title` and
`utility.pit.hint`. The App Shortcut titles stay in the app's
`Localizable.xcstrings`; the shortcut provider stays in the app only.

## Tests

`PitstopTests/SystemCapture/WidgetEntryTests.swift` (ADR-0025,
REQ-CAPTURE-023), hosted in the app so the embedded extension is read from the
built product:

- **URL routing:** `CaptureSurface.pit.url` is `pitstop://pit` and parses back;
  `pitstop://pit`, a trailing slash, and upper case request Pit; twelve other
  URLs (other hosts, sub-paths, query, fragment, user, port, `pitstop:pit`,
  empty host, `https`, another scheme) return false and leave nothing pending;
  a Pit URL while an editor is presented stays pending and opens Pit once
  unblocked; the app's `CFBundleURLTypes` declares exactly the `pitstop`
  scheme.
- **Extension:** `PlugIns/PitstopWidgets.appex` exists with bundle ID
  `dev.vil4max.pitstop.widgets`, the WidgetKit extension point, and the app's
  `CFBundleShortVersionString` and `CFBundleVersion`; both bundles' metadata
  declare `OpenPitIntent` with the `OpenEntity` protocol and only the main
  execution target, and the extension declares no other intent; the
  `OpenPit` table is identical in both bundles for en, ru, and uk; every
  control and widget key resolves in the three locales.
- **Shortcut:** `AppShortcutsTests` still passes unchanged (two shortcuts,
  Remember then Open Pit); a new test checks that `CaptureSurface` has one
  case and that the extracted `target` parameter carries the default `pit`.

The control and widget are declarations without logic; they are checked in
the built product and on the simulator, not by unit tests.

## Rejected alternatives

- **A hidden control-only `OpenIntent`** (owner fallback). Not needed: the
  shared intent keeps the App Shortcut and its tests working.
- **Per-target string catalogs with duplicated intent keys.** Would let the
  two bundles drift; one shared table is compiled into both.
- **A shared framework with `AppIntentsPackage`.** Correct but a third target
  for four small files (SYS-004).
- **`onOpenURL` in `RootView`.** Misses a cold-launch URL while the DEBUG
  preparation placeholder is shown.
- **Accepting any `pitstop://` host and ignoring the rest silently in
  SwiftUI.** A parsed allow-list with one entry keeps the public scheme from
  growing by accident and is testable without UI.
- **Creating the target with Xcode's template.** SYS-004 recommended it, but
  Xcode 27.0 may write back a `project.pbxproj`, and the OneCart JSON shape
  is a known working reference; the hand-written diff is small and reviewed.
- **Data widget, interactive capture buttons, background capture.** See
  SYS-004; the data widget is the SYS-007 proposal.

## Open items

- **Device checks (with SYS-006):** the control in the Lock Screen and Action
  button pickers and its "Hold to Open" hint; a locked-phone tap asks for
  unlock before the app shows anything; the Lock Screen circular widget.
- **Simulator gallery checks:** adding the widget to the Home Screen and the
  control to Control Center needs gallery gestures that were not performed in
  SYS-005; the URL route was checked with `simctl openurl` instead.
- **Shortcuts listing:** whether the Shortcuts app lists Open Pit once now
  that two bundles declare it.
- **Data widget:** delivered by SYS-007 in ADR 0036 (App Group, store move,
  read-only store in the extension, `pitstop://service`). It changes two
  statements above: both targets now have entitlements, and domain and
  persistence files enter the extension through membership exceptions.
- **Xcode Cloud:** the first TestFlight archive with the extension confirms
  signing of `dev.vil4max.pitstop.widgets` (automatic signing registers the
  new ID).
