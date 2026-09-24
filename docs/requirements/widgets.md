# Widgets with Car Data

**Status:** proposed (SYS-007); the data-free capture widget and the Open Pit
control stay under [`capture-pipeline.md`](capture-pipeline.md)
(REQ-CAPTURE-023) and ADR 0025

Core: P1, P2, C2

Decision record: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md).

## Scope

One Home Screen and Lock Screen widget, "Next service", shows the operation
Service lists first. It reads the car memory; it never writes it. To make the
store readable by the extension, the app moves it into the App Group container
once. No photo, note text, amount, car name, or analytics ever reaches a
widget.

## Requirements

### REQ-WIDGET-001 — The store moves into the App Group container once, without loss
Status: proposed
Core: P1
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given a store of schema V2, V3 or V4 in the app's own container
When the app launches for the first time with the App Group
Then the store and its `-wal` and `-shm` files are copied into the group
container, the copy opens under the current schema with every fact intact, the
copy is marked as the store, the old files are removed, and later launches
change nothing

### REQ-WIDGET-002 — A failed or interrupted move keeps the old store
Status: proposed
Core: P1
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given a move that fails to copy a file, to open the copy, or to mark it, or
that was interrupted before the mark
When the app opens its store
Then it opens the untouched old store, the failure is logged, and the next
launch moves it again, even when a stale partial copy cannot be deleted; once
the copy is marked, a file left at the old location is deleted only while it is
exactly what was copied, and otherwise renamed to a dated backup and kept.
Known limitation: facts written there by a downgraded build are kept as that
backup, not merged into the group store

### REQ-WIDGET-003 — A fresh install starts in the group container
Status: proposed
Core: P2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given no old store
When the app launches
Then the store is created in the group container; without an App Group
container the old location stays in use unless the store was already moved,
in which case nothing durable opens and the app says nothing will be kept; a
store that cannot open still falls back to memory as before

### REQ-WIDGET-004 — The widget shows the operation Service lists first
Status: proposed
Core: C2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given tracked operations
When the widget builds its entry
Then it runs the same maintenance engine on the same facts as Service and
shows the first operation in Service's order by name, status word and one
fact, such as "Engine oil service · Approaching · in 1,200 km" or "Due"
Amended by REQ-WIDGET-011: when the content does not fit at the current text
size, the fact and then the status word may be dropped.

### REQ-WIDGET-005 — Unknown and partial states read as on Service
Status: proposed
Core: C2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given an operation without a baseline, or one decided by its date while its
distance cannot be counted
When the widget shows it
Then it says "Not enough facts" or "Up to date by date" / "Approaching by date"
with the reason the distance is not counted, never a number the facts do not
support
Amended by REQ-WIDGET-011: the reason is part of the fact line and may be
dropped when the content does not fit, as on the Lock Screen at the default
text size when the name or the status word fills the slot.

### REQ-WIDGET-006 — Empty and unreadable states are calm and open the app
Status: proposed
Core: P2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given no car, nothing tracked, no moved store yet, or a store that cannot be
read now
When the widget shows
Then it invites the person to open PitStop without a placeholder metric or
alarm; an unreadable store is tried again later

### REQ-WIDGET-007 — A tap opens Service
Status: proposed
Core: P2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given the widget
When the person taps it
Then the app opens on Service through `pitstop://service`; the link waits while
a sheet or an editor is open, and no other `pitstop://` link opens anything new

### REQ-WIDGET-008 — The widget only reads
Status: proposed
Core: P1
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given the widget extension
When it reads the store
Then it opens the marked group store read-only, fetches only maintenance
policies, completions, dashboard readings, odometer readings and whether a car
exists, never migrates an older store, and leaves the database and its
write-ahead log byte for byte as it found them (only SQLite's shared-memory
index changes, as it does for any reader); its content is marked
privacy-sensitive (checked on the device, not by a unit test)

### REQ-WIDGET-009 — A saved command reloads the widget
Status: proposed
Core: P1
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given the durable store in the app
When a domain command is saved
Then the app asks WidgetKit to reload the next-service widget once; a rejected
or failed command, a read, or a temporary store asks for nothing; each launch
that opens the durable store also reloads it once

### REQ-WIDGET-010 — The widget refreshes when time alone changes it
Status: proposed
Core: C2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md)
Given a shown operation whose status or fact changes with time, such as a date
anchor, a day count, or mileage going stale
When the widget builds its timeline
Then it asks to be reloaded at the first moment its content changes, and not
sooner than five minutes; content that time cannot change asks for no
scheduled reload

### REQ-WIDGET-011 — Content that does not fit drops lines by priority
Status: approved (owner, 2026-09-24)
Core: C2
Source: [ADR 0036](../decisions/0036-app-group-store-and-next-service-widget.md), FU-2
If the widget's content does not fit at the current text size, the widget
shall drop lines in this order: first the "Next service" eyebrow, then the
fact (with the by-date reason), then the status word, keeping the status
glyph; the operation name and the status shall stay visible, the name shall
wrap whole before any lower line is dropped and may end in an ellipsis only
in the last layout, and a status word shall never be truncated.
Acceptance: Given an operation whose content does not fit, When the widget
lays it out, Then the dropped lines follow this order and a tap still opens
Service.

### REQ-WIDGET-012 — VoiceOver reads the whole content
Status: approved (owner, 2026-09-24)
Core: P5
Source: FU-2
When VoiceOver reads the widget, the widget shall speak the operation name,
the status word and the fact, including lines the layout dropped; while the
content is redacted for privacy, it shall speak only the widget's name
(REQ-WIDGET-008).
Acceptance: Given the widget shows an operation in any layout, When VoiceOver
reads it, Then it hears the full content, or only the widget's name when
redacted.
