# pitstop-ios

Personal car diary: odometer, service visits, reminders, and insurance for your vehicle.

**Pitstop** ships with optional demo data for one vehicle. Future versions can support multiple cars by adding a vehicle manually or decoding a VIN to pre-fill make, model, and year.

## Distribution

- **Bundle ID:** `dev.vil4max.pitstop` (new App Store listing; not an update from `dev.vilchevskyi.arteon`)
- **SwiftData:** no automatic migration between bundle IDs; fresh install or manual re-import
- **Notifications:** permission must be granted again on the new bundle
- **iCloud (future):** `iCloud.dev.vil4max.pitstop`

## Screenshots

Launch → My car → Service (default tab order).

<p align="center">
  <img src="screenshots/01-launch.png" width="220" alt="Launch screen" />
  <img src="screenshots/02-my-car.png" width="220" alt="My car — odometer and status widgets" />
  <img src="screenshots/03-service.png" width="220" alt="Service — visit schedule and task lists" />
</p>

## Stack

iOS 26+ · Xcode 26+ · SwiftUI · SwiftData · Foundation Models · UserNotifications · Swift Testing + XCTest · en / uk / ru · MVVM

Product and engineering specs: [`specs/`](specs/)
