# App Group Store and the Next-Service Widget

**Status:** Accepted for implementation (owner approved the data widget and
registered the App Group `group.dev.vil4max.pitstop` on both App IDs,
2026-09-22); requirements REQ-WIDGET-001…010 proposed; owner device checks
pending\
**Task:** SYS-007 ("Widget with car data: App Group, store move, next-service widget")\
**Investigation:** [`../planning/investigations/sys-004-widgets.md`](../planning/investigations/sys-004-widgets.md),
"Cost of a data widget"\
**Changes:** [`0007-persistence.md`](0007-persistence.md) (store location,
second reader), [`0025-widgets-and-controls.md`](0025-widgets-and-controls.md)
(entitlements, shared files, a second link)\
**Contracts:** [`../requirements/widgets.md`](../requirements/widgets.md)
(REQ-WIDGET-001…010, proposed); core P1 (facts are the owner's), P2 (the app
always opens), C2 (no invented facts)

## Context

ADR 0025 shipped a data-free widget and control and left a widget with car data
to SYS-007. The widget extension is a separate process with its own sandbox:
it cannot read `Application Support/Pitstop.store` in the app's container,
where ADR 0007 put the store. TestFlight testers already hold stores of schema
V2, V3 or V4 there, so relocating the file must not lose or fork their data.

Platform facts used here (Apple documentation, read through the Cupertino
index on 2026-09-22):

- `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` returns
  the group container, or `nil` on iOS when the identifier is not in the app's
  App Groups entitlement. On iOS the system creates only `Library/Caches`
  inside it; other directories are the app's to create.
- `ModelConfiguration(schema:url:allowsSave:)` with `allowsSave: false` makes
  the persistent storage read-only.
- WidgetKit budgets reloads per widget, typically 40 to 70 a day, and does not
  count a reload requested while the containing app is in the foreground.
  `WidgetCenter.shared.reloadTimelines(ofKind:)` reloads one kind.
  `TimelineReloadPolicy.after(_:)` asks for a new timeline at a date; entries
  should be at least about five minutes apart ("Keeping a widget up to date").
- Core Data's default file protection for a persistent store is
  `completeUntilFirstUserAuthentication`
  (`NSPersistentStoreFileProtectionKey`), so the extension can read the store
  after the first unlock following a restart, and not before.
- `NSFileCoordinator` coordinates file presenters; an app or extension that
  goes to the background with an active file presenter may be terminated. The
  store is a SQLite database whose own locking serialises the app and the
  extension; neither process registers a presenter.

## Decision

### App Group and entitlements

`Config/Pitstop.entitlements` and `Config/PitstopWidgets.entitlements` hold
only `com.apple.security.application-groups` = `group.dev.vil4max.pitstop`,
wired through `CODE_SIGN_ENTITLEMENTS` on each target. Signing stays
automatic. The files live in the `Config` group rather than the synchronized
folders, so no membership exception is needed for them.
`Pitstop/Pitstop.entitlements.example` (iCloud) stays excluded, as ADR 0005
says.

### Store location and the move

`StoreLocation` names the group store
`<group>/Library/Application Support/Pitstop.store`, a group marker
`.Pitstop.store.moved` beside it, and an app marker
`.Pitstop.store.in-app-group` beside the old store in the app's own container.
The group marker is JSON recording the size and modification date of each old
file the move copied (empty on a fresh install). The app marker is a file
rather than a `UserDefaults` value so that it follows the files. The store is
passed to SwiftData as an explicit URL, so adding the entitlement alone never
relocates it (`GroupContainer.automatic` is not used).

`StoreRelocation.prepare()` runs in `AppEnvironment` before the first
`ModelContainer` opens, only for the durable store (never for
`-pitstop-in-memory`, previews, or the DEBUG demo):

1. **Group marker present:** the group store is the car memory. A file still at
   the old location is compared with the recorded identities. If every file
   matches, it is the copied store whose deletion failed earlier, and it is
   deleted. Otherwise, for example when a downgraded build wrote a new store
   there, it is renamed to a dated backup beside it
   (`Pitstop.store.leftover-YYYYMMDD-HHMMSS` plus its `-wal`/`-shm`), logged,
   and neither deleted nor merged. If the rename fails, the files stay
   untouched and the next launch tries again.
2. **No group marker, no old store:** a fresh install. The directory and both
   markers are written and the group store starts there.
3. **No group marker, old store present:** anything in the group location is an
   unfinished copy. The `.store`, `-wal` and `-shm` files are copied under
   names no earlier attempt used, and each is renamed over its final name
   (POSIX `rename` replaces a stale file even when it could not be deleted, so
   a stale copy never blocks the move). A sidecar the old store lacks is
   written empty, so a stale `-wal` can never be replayed into the copy. Then
   the copy is opened under the current schema and migration plan and read,
   the group marker is written, then the app marker, and only then are the old
   files removed. If the app marker cannot be written, the old files stay as
   the fallback; the next launch writes the marker and deletes them because
   they still match.
4. **Any failure before the group marker** (copy, open, or marker) removes the
   partial copy as far as it can, keeps the old store in use, logs the step,
   and the next launch tries again.
5. **No App Group container:** without the app marker (never moved), the old
   location stays in use. With it, the car memory is in a group this build
   cannot reach: the app opens the in-memory store with the existing "nothing
   will be kept" notice instead of an empty durable store at the emptied old
   location, where the owner would believe the data lost and write new facts.

The move never destroys unidentified data: old files are deleted only after a
copy that opens has been marked, and only when they are still exactly what was
copied. The in-memory fallback of ADR 0007 is unchanged: whichever URL the move
returns is opened as before, and a store that cannot open still falls back to
memory with the Settings notice. Every launch that opens the durable store asks
the widget to reload once, so a widget left empty or unavailable before this
launch moved or migrated the store shows it.

**Known limitation:** facts written by a downgraded build at the old location
are kept as a backup file, not merged into the group store. Merging two
diverged stores is not worth its risk for the one TestFlight tester who could
downgrade. The backup is kept, not lost, but a TestFlight install gives nobody
access to the app container: recovering it would need a future in-app export or
a development build. Only a downgrade followed by a re-upgrade creates a backup,
and backups are not capped.

### Read-only widget access

The extension compiles the domain and persistence files it needs through
membership exceptions of the synchronized `Pitstop/` folder (the JSON project's
`exclusions` list for a target that is not a member of the folder adds files
to it, as a `PBXFileSystemSynchronizedBuildFileExceptionSet` does): the
maintenance domain (`Maintenance`, `MaintenanceEngine`,
`VehicleServiceReport`), `Vehicle`, `ProvisionalCarContext`,
`DomainCommandLimits`, the four schema versions, `PersistenceContainer`,
`RecordMapping`, `StoreLocation` and `NextServiceStoreReader`. To keep that set
small, `DomainCommandLimits` moved out of `DomainCommands.swift` and the note,
History and planned-date record mappings moved into the app-only
`MemoryRecordMapping.swift`. No engine rule is restated in the extension.

`NextServiceStoreReader.facts(at:)` opens the store with
`PersistenceContainer.makeReadOnly` (`allowsSave: false`, no migration plan),
fetches whether a car exists and the maintenance policies, completions,
dashboard readings and odometer readings, maps them to domain values, and
releases the container before returning. A store of another schema version
fails to open instead of being migrated by the extension; tests check that the
database and its write-ahead log stay byte for byte after a read and after a
refused older store (only the `-shm` shared-memory index, which every SQLite
reader updates, may change). The reader opens a store only when its
marker exists, so it never reads a copy in progress. Notes, History and plans
are never fetched.

### The widget

`NextServiceWidget` (`systemSmall`, `accessoryRectangular`,
`accessoryInline`; kind `dev.vil4max.pitstop.widgets.nextService`) shows
`NextServiceContent`, built in `Shared/NextServiceContent.swift`:

- The same `MaintenanceEngine` on the same inputs as `ServiceViewModel`, and
  the first element of `byUrgency`, which is Service's first row.
- `statusWord` and `progressFact` are decided once in `Shared/` and used by
  Service, Car Board and the widget; each bundle words them in its own string
  catalog. Service's `statusLabel` and `progressText` now map those values;
  their wording is unchanged.
- Empty (no car, nothing tracked, no moved store yet) and unavailable (store
  cannot be read now; retried after 30 minutes) states invite the person to
  open the app. The gallery and placeholder show a fictional sample.
- Only the operation name, the status word and one fact are shown; the
  content is `privacySensitive`. No photo exists yet (RD-012), and none is
  added.
- A tap opens `pitstop://service`. `AppLink` (`Shared/AppLink.swift`) is the
  closed list of links (`pit`, `service`) with ADR 0025's strict parser;
  `CaptureSurface` stays a one-case `AppEnum`, so the Open Pit intent is
  unchanged. `AppLinkRouter` turns a link into `CaptureSurfaceRequests` or the
  new `ServiceLinkRequests`; `RootView` opens Service when no sheet or editor
  is presented, otherwise the request waits.

### Reloads

`WidgetReloadingCarMemoryStore` wraps the durable store: after `execute`
returns, it calls `NextServiceReloading.reloadNextService()`, whose live
implementation calls `WidgetCenter.shared.reloadTimelines(ofKind:)`. A
rejected or failed command throws first and asks for nothing; reads pass
through. Writes from the app in the foreground do not spend the widget's
budget. "Remember in PitStop" can save while the app runs in the background,
and that reload does count; the widget still reloads, because showing current
facts matters more than the budget, and such saves are rare against the
typical 40 to 70 reloads a day.

Time-based changes are scheduled by the timeline itself:
`NextServiceSchedule.nextChange` evaluates the same content forward in daily
steps up to 400 days and narrows the first change to the minute, so a date
anchor turning an operation approaching or due, a day count ticking, or the
mileage going stale each schedule a reload at that moment
(`.after(date)`, never sooner than five minutes). Content that time cannot
change uses `.never`.

## Tests

- `PitstopTests/Persistence/StoreRelocationTests.swift`: fresh install; V2, V3
  and V4 stores moved and opened with their facts (planned dates, dashboard
  readings); an interrupted copy redone; a stale unmarked copy that cannot be
  deleted does not block the move; an old store changed after the move kept as
  a dated backup with its facts while the group store keeps newer ones; an old
  store identical to the copy deleted on the next launch; a failed copy of each
  of the three files, a copy that does not open, and a failed marker all keep
  the old store and leave no partial copy; no App Group container before and
  after a move; a failed backup rename puts back the files it already renamed.
  The App Group entitlement itself is checked on the device and by the Xcode
  Cloud archive (DEV-WIDGET): on the simulator the group container resolves
  whatever the signing.
- `PitstopTests/Widgets/NextServiceWidgetTests.swift`: empty (no car, nothing
  tracked), one operation, the most urgent choice equal to Service's first row
  (same summary), unknown and partial states, Service's partial wording
  unchanged; refresh at mileage staleness, a day count and a due date, the
  five-minute floor, and no refresh without a time-based change; the
  unavailable retry and the no-store state; the reader returns what the store
  returns, dashboard readings included, without changing a data byte, reads
  beside an open app container, never migrates a V3 store, and ignores an
  unmarked store.
- `PitstopTests/Widgets/NextServiceReloadAndLinkTests.swift`: a reload after a
  saved command and none after a rejected or failed one; the durable store is
  wrapped for reloads and a temporary one is not; the `pitstop://service`
  link, its deferral, and that other links still open nothing. `RootView`'s
  gate (a sheet or editor blocks the link) and `privacySensitive` are not
  unit-tested: they are view wiring, checked on the device.
- `WidgetEntryTests`: every next-service string key, including the plural day
  counts, resolves in en, ru and uk in the extension.

## Rejected alternatives

- **`ModelConfiguration.GroupContainer.automatic` or `.identifier`.** It
  would choose the location implicitly; with an explicit URL the move is a
  visible, tested step, and the entitlement alone moves nothing.
- **Opening the store from both locations, or keeping the app store and
  exporting a snapshot file for the widget.** Two copies drift; a snapshot
  needs its own format, versioning and write path. One store, one writer.
- **Core Data's `replacePersistentStore` or `migratePersistentStore` for the
  move.** Correct, but it adds Core Data coordination for three files that are
  closed at that moment; a plain copy plus an open-and-read check is simpler to
  test with failure injection.
- **Moving the files with `moveItem`.** A crash between the three moves could
  split the store across containers; copy, verify, mark, then delete never
  leaves the only data in a half state.
- **The extension opening the store read-write, or with the migration plan.**
  It could migrate or write the owner's store from a background process.
- **`NSFileCoordinator` or a file presenter.** SQLite already serialises the
  two processes; a presenter risks termination in the background.
- **Duplicating the engine or a slimmer status rule in the extension.** Two
  rule sets would disagree near an anchor; the extension compiles the engine.
- **A fixed hourly or daily timeline.** Spends budget without new content and
  still misses the exact moment a date anchor turns due.
- **Adding `service` to `CaptureSurface`.** It would change the Open Pit
  intent's parameter and App Shortcut metadata.

## Consequences and limits

- ADR 0007: the store file is now the group store; the app is still the only
  writer, and the widget is a second, read-only reader. The provisional-car
  note in ADR 0007 still holds because the extension never writes.
- ADR 0025: both targets now have entitlements, and domain and persistence
  files enter the extension through membership exceptions.
- A store the app cannot open (for example one written by a newer build) is
  not moved: the copy fails verification, the old store stays, and the app
  falls back to memory as before.
- The widget's first timeline after an upgrade is empty until the app has
  launched once and moved the store.
- Facts a downgraded build writes at the old location survive only as a dated
  backup beside it; nothing merges them (known limitation above).

## Open items

- **Owner device checks:** the widget appears in the gallery with the fictional
  sample; Home Screen, Lock Screen rectangular and inline families render; a
  tap opens Service; a locked phone redacts the content.
- **TestFlight upgrade check:** install the current TestFlight build with
  data, upgrade to this build, confirm the data is intact on Service and the
  widget shows the first operation.
- **Xcode Cloud:** the first archive confirms that automatic signing includes
  the App Group in both profiles.
- RD-009 restyles the widget with the design system; it keeps this data path.
