# pitstop-ios

Smart driver's journal and contextual car memory for your vehicle (greenfield rebuild on `main`).

**Legacy tab-bar spike** (pre–Car Board): branch [`legacy/spike`](https://github.com/vil4max/pitstop-ios/tree/legacy/spike).

## Distribution

- **Bundle ID:** `dev.vil4max.pitstop` (new App Store listing; not an update from `dev.vilchevskyi.arteon`)
- **SwiftData:** no automatic migration between bundle IDs; fresh install or manual re-import
- **Notifications:** permission must be granted again on the new bundle
- **iCloud (future):** `iCloud.dev.vil4max.pitstop`

## Screenshots

Legacy UI (tab bar) — see `legacy/spike`. Greenfield screenshots TBD after Car Board ships.

## Stack

iOS 26+ · Xcode 26+ · SwiftUI · SwiftData · Foundation Models · UserNotifications · Swift Testing + XCTest · en / uk / ru · MVVM

Product and engineering specs: [`specs/`](specs/)
