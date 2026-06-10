# pitstop-ios

iOS **17+**, **SwiftUI**, **SwiftData**. Local storage only, no backend.

Developer pet project: sandbox for **AI-assisted iOS development** (Cursor). The codebase is a single-vehicle maintenance tracker with JSON seed data — not a product, not on the App Store.

**Scope:** one hardcoded vehicle profile; service visits, insurance dates, upgrades, local notifications.

---

## Stack

| | |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData (local) |
| Notifications | `UserNotifications` |
| Tests | Swift Testing + XCTest (`ArteonTests`) |
| Locales | en, uk, ru |

---

## Modules

| Tab | Function |
|-----|----------|
| My Car | Odometer, status widgets |
| Service | Visit schedule, task lists, completion flow |
| Upgrade | Item list, dealer visit log |
| Settings | Theme, notification schedule |

---

## Build

Xcode **16+**, scheme **Arteon**, bundle `dev.vilchevskyi.arteon`.

```bash
git clone https://github.com/vil4max/pitstop-ios.git
cd pitstop-ios
open Arteon.xcodeproj
```

---

## License

MIT
