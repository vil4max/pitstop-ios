# My Arteon / Мой Артеон

Personal **maintenance tracker** for one car: **Volkswagen Arteon** (2024, TDI). **iOS 17+** only. No backend — data stays **on device** (iCloud sync deferred until paid Apple Developer Program).

**App name on device:** **My Arteon** (en) · **Мій Артеон** (uk) · **Мой Артеон** (ru).

Open source (MIT). v1 is **single-vehicle only**; maintenance fundament is `Resources/maintenance-plan.json` (seeded once into SwiftData on first launch).

---

## Data fundament

| Layer | Role |
|-------|------|
| Owner rhythm | Oil every **5–7k km**; user plan **~20k ±2k** |
| `averageMonthlyMileageKm` | **563** — date estimates only |
| `maintenance-plan.json` | Last oil **11k** → next **16–18k** |
| **SwiftData** | Runtime odometer, task checkmarks, visit completion |

**Now:** **13 600 km**; **2 600 km** since oil @ **11k**; next oil **16–18k**.

---

## Why SwiftData (v1)

Data is simple (scalars + relationships), but SwiftData gives:

- **Native SwiftUI** — `@Query` in views without hand-rolled sync
- **Relationships** — visits ↔ tasks with cascade delete
- **External storage** — car photo via `@Attribute(.externalStorage)`
- **One stack** — same patterns if CloudKit is added later on paid account

**Trade-off:** schema migrations need care on model changes. v1 models are stable; JSON seed is read-only after first import. Alternative for v2: JSON file + atomic write — less framework surface, more manual code.

---

## v1 scope

| In v1 | v2+ |
|-------|-----|
| 4 tabs, seed data, local notifications | OSAGO PDF import |
| Service carousel, task lists, complete/reopen visit | In-app TO plan editing |
| Insurance QR + edit dates | iCloud sync (paid dev account) |
| Upgrades done (₴) + planned ($) | macOS target |

---

## Design

| Token | Dark | Light |
|-------|------|-------|
| **Canvas** | `#051A40` | System grouped background |
| **Accent** | `#0B2556` | Same on light canvas |
| **Units** | km only, ₴ for spent, $ for planned upgrades |

---

## Tabs

| Tab | Purpose |
|-----|---------|
| **My car** | Photo, vehicle info, odometer, pills, Atlant total, insurance link |
| **Service** | Oil summary, **visit carousel**, task lists, complete visit (with confirmation) |
| **Upgrade** | Done **83 000 ₴** · planned **$5 500** |
| **Settings** | Theme, **notification schedule**, iCloud note, disclaimer |

---

## Notifications

- Auto-reschedule on launch, odometer change, insurance edit, visit complete/reopen
- **Settings → Notification schedule** — toggles + list of upcoming reminders
- Categories: monthly odometer, oil due, seasonal May/Nov, OSAGO −30/−7/−1 days

---

## Technology

- SwiftUI, SwiftData (local), Swift Testing + XCTest
- `MaintenanceEngine` — pure oil/visit logic
- `NotificationPlanBuilder` — testable schedule planning
- Locales: **en**, **uk**, **ru** (`Localizable.xcstrings`)

---

## Project layout

```
Arteon/
  App/              ArteonApp, tabs, AppConfiguration
  Features/         MyCar, Service, Upgrade, Settings, Insurance
  Core/             Engine, Persistence, Notifications
  DesignSystem/     VWCard, Odometer, QR
  Resources/        JSON seeds, xcstrings
ArteonTests/
scripts/
  import_maintenance_from_xlsx.py
```

Open in **Xcode 16+**, scheme **Arteon**, bundle ID `dev.vilchevskyi.arteon`.

---

## Regenerate maintenance JSON

```bash
python3 scripts/import_maintenance_from_xlsx.py
```

---

## Repository

`~/Developer/GitHub/pitstop-ios`

See [AGENTS.md](AGENTS.md) for product spec and manual QA checklist.
