# PitStop

Smart driver's journal and contextual car memory for your vehicle.

**Project state:** Frozen — see [`PROJECT_STATUS.md`](PROJECT_STATUS.md).  
**Resume next task (when unfrozen):** DOM-002 — spec-derived domain test fixtures.  
**Legacy tab-bar spike:** branch [`legacy/spike`](https://github.com/Engineering-University/pitstop-ios/tree/legacy/spike).

## Distribution

- **Bundle ID:** `dev.vil4max.pitstop` (new App Store listing; not an update from `dev.vilchevskyi.arteon`)
- **SwiftData:** no automatic migration between bundle IDs; fresh install or manual re-import
- **Notifications:** permission must be granted again on the new bundle
- **iCloud (future):** `iCloud.dev.vil4max.pitstop`

## Stack

iOS 26+ · Xcode 26+ · SwiftUI · SwiftData · Foundation Models · UserNotifications · Swift Testing + XCTest · en / uk / ru · MVVM

Product and engineering specs: [`specs/`](specs/)
