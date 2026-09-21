# Planned Dated Events

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-22); owner review pending\
**Task:** ROAD-EVT-001\
**Builds on:** [`0008-road-projection-rules.md`](0008-road-projection-rules.md)
(14-day grace after a planned date), [`0007-persistence.md`](0007-persistence.md)
and [`0016-question-registry.md`](0016-question-registry.md) (versioned schema,
frozen versions, lightweight stages), [`0031-stop-tracking-an-operation.md`](0031-stop-tracking-an-operation.md)
(user-only command and confirmation pattern)\
**Source:** [MNT-INT-001](../planning/investigations/mnt-int-001-maintenance-intelligence.md),
area 3, candidates R1 and R4\
**Contracts:** [`../requirements/road-domain-and-ui.md`](../requirements/road-domain-and-ui.md)
(REQ-ROAD-016…021, proposed)

## Context

Road could already place a planned date: `RoadContext.plannedEvents` and the
`insuranceExpiry`, `plannedVisit` and `other` kinds existed, and ADR 0008 set
the 14-day grace after the date. Nothing stored a date and nothing let the owner
enter one, so the app always passed none. MNT-INT-001 chose owner-stated dates,
insurance expiry first, over any derived date: deriving an inspection or
insurance date from law, locale, registration year or a mileage rate breaks
core C2 and REQ-ROAD-007.

The investigation left three owner questions. The owner delegated them on
2026-09-21 ("do everything"); the answers below are agent decisions that the
owner may still reverse.

## Decision

1. **Entry point: the Road screen.** An "Add a date" toolbar button, also
   offered in Road's empty state, opens an editor sheet. A planned row on the
   Road list has a "More" menu with Edit and Delete, and the same two actions
   are VoiceOver custom actions on the row. Road is where the date is shown,
   so it is where it is corrected. The Car Board header stays the car's
   identity and mileage, and a planned date is not a History fact, so the
   History editor is the wrong home (core C5). Remember may propose a date
   later only behind confirmation (ADR 0006); no proposal maps to these
   commands now.
2. **`other` has an optional short label.** One trimmed line of at most 40
   characters, typed by the owner and shown verbatim on Road, never
   translated. Without one Road says "Planned event". The label exists because
   R3 and R4 dates ("winter tyres", "warranty ends") are unreadable without a
   name. Insurance has no label and no other field: the record has no column
   for an insurer, a policy number or an amount, so none can be stored.
3. **Insurance shows on Road only.** The Car Board Road tile already projects
   Road, so a stated expiry reaches Car Board through it. No separate tile or
   header line is added: the four-tile V1 layout is fixed (ADR 0009), and a
   second place would have to agree with Road for no new information.
4. **Domain.** `PlannedDatedEvent` (ID, vehicle ID, kind `insuranceExpiry` or
   `other(label:)`, date, creation time) is the stored value. `roadEvent`
   turns it into the existing `PlannedVehicleEvent` projection input, which
   gained an optional `label`; `RoadMilestone.plannedLabel` carries it to the
   surface. `plannedVisit` stays a projection kind with no storage; it waits
   for owner question C of ADR 0020 (Service Plan order).
5. **Three user-only commands.** `addPlannedEvent`, `updatePlannedEvent` and
   `removePlannedEvent` go through `CarMemoryStore.execute` like every other
   write. Command validation: the date lies between 14 days ago and 3,650 days
   ahead (`plannedDateOutOfRange`), and a label is one trimmed, non-blank line
   (`invalidPlannedLabel`) within the limit (`plannedLabelTooLong`). The store
   requires the current vehicle, rejects a repeated ID (`duplicateRecord`),
   rejects an unknown ID on update or remove (`unknownPlannedEvent`), and keeps
   the stored ID, vehicle and creation time on update, so a correction can
   never move a plan to another car. A rejected command saves nothing.
6. **One insurance expiry on Road per car.** Adding one, or turning another
   date into one, while an insurance expiry is still on Road fails with
   `insuranceExpiryAlreadyPlanned`; correcting the one on Road is allowed. An
   expiry that has left Road does not count, so a renewal can be planned. The
   editor offers only "Other date" while an expiry is on Road. Two unlabelled
   "Insurance ends" rows would be indistinguishable; a second policy is an
   `other` date with its own label.
7. **Store query.** `CarMemoryStore.plannedEvents()` returns every stored date,
   earliest first. The Road screen and the Car Board tile both feed it into
   `RoadContext`, so they agree (REQ-BOARD-010). The projection alone decides
   what is on Road (REQ-ROAD-004).
8. **Dates are days.** The editor stores the start of the chosen day in the
   owner's calendar, not the time the date was typed. The picker runs from
   today (or from the stored date, when correcting one that has just passed)
   to the last whole day within the limit, so it offers nothing the command
   rejects. Road counts a planned date in whole days: a day still to come counts
   in full, so at 10:00 tomorrow is "1 day left" and a date 40 days ahead is
   "40 days left", not "almost" and 39 (a fix from independent review; the
   projector truncated fractions before).
9. **Leaving Road.** A date stays on Road as due for 14 days after it passes
   and then leaves (ADR 0008); the row stays in the store. Nothing deletes it
   automatically: a hidden cleanup would be a write nobody asked for, and the
   row is a handful of bytes.
10. **Schema V3, V2 frozen.** `PitstopSchemaV3` is V2 plus
    `PlannedVehicleEventRecord` (id unique, vehicleID, kind, optional label,
    date, createdAt), reached by a second lightweight stage. V1 and V2 classes
    are reused, so V2 is now frozen like V1: `PersistenceSchemaTests` pins its
    shape, as TestFlight `tf-1.1.0-2` shipped it. A stored kind this version
    cannot read maps to `other` with its label, so it stays visible and
    deletable and never blocks an insurance expiry.
11. **Pit and analytics.** The editor sheet, the delete dialog and a delete
    failure report `.modalTask` to Pit (ADR 0019). No analytics event is added:
    the measurement questions in MNT-INT-001 need a closed event design and
    consent (ADR 0021), which is its own task.

## Consequences

- REQ-ROAD-001 ("explicit meaningful planned vehicle event") and the "Insurance
  expiry (known)" eligibility row are reachable in the app for the first time.
- `DomainCommand` and `CommandResult` gained three cases each. No proposal maps
  to them; `PitDestination` treats the results as Car Board, which leads to
  Road, should a mapping ever be added.
- A TestFlight build with V2 only cannot open a store that V3 migrated; a
  downgrade falls back to temporary storage, as ADR 0016 describes for V1.
- Expired dates accumulate in the store. If that ever matters, a user-visible
  "past plans" list or a cleanup needs its own decision.
- The 3,650-day limit and the 40-character label are hypotheses; beta evidence
  on rejected saves and truncated labels would revise them.
- The grace boundary is exact: a date stored as the start of day D leaves Road
  at the start of D+14, so the row reads "13 days past" at most. ADR 0008 does
  not say whether "14 days" is inclusive; changing it touches every planned
  milestone and is left to the owner's review.
- The stored start of day belongs to the time zone it was saved in. After a
  time-zone change the picker can show the neighbouring day, and saving an
  edit re-normalises to it. Storing a calendar day (year, month, day) instead
  of a moment would remove this; it needs a schema version and was not worth
  one for a rare case.
- DEBUG demo data (`-pitstop-demo-data`) now includes a fictional insurance
  expiry 40 days ahead.

## Rejected alternatives

- **Car Board header or a fifth tile for insurance.** Duplicates Road and breaks
  the fixed V1 tile order (ADR 0009).
- **History editor entry.** History holds performed facts; a plan there would
  blur planned and performed work, which the domain forbids (core C5).
- **Remember-only entry.** Needs a new proposal kind, a mapper and a
  confirmation copy before the store itself is proven; it can follow.
- **Free-text note on insurance (insurer, policy number).** The investigation
  scoped the record to the date; such text is personal data this public,
  local-first app has no reason to hold.
- **Allowing several insurance expiries.** Needs a label on insurance to be
  readable, which reopens the "no insurer name" rule.
- **Adding the record to V2 in place.** A store written by `tf-1.1.0-2` would
  match no schema version and fail to open (ADR 0016).
- **Deriving the next expiry (for example "one year after the last").** A
  derived date is invented truth (core C2); the owner states the renewal.
- **Swipe actions on the row.** Road rows are cards in a scroll view, not a
  `List`; the "More" menu matches Service (ADR 0031).

## Verification

- `PitstopTests/Road/PlannedDatedEventTests.swift`: the date window and label
  rules of the commands, the Road input carrying only kind, date and label,
  days-left labelling, the owner's label on the milestone, and the 14-day
  grace (on Road through day 14, gone after, still stored).
- `PitstopTests/Persistence/SwiftDataPlannedEventTests.swift`: round trip and
  reopen, correction keeping identity and creation time, removal, rejected
  commands saving nothing (date, label, vehicle, duplicate, move to another
  vehicle), one insurance expiry on Road, an unknown stored kind, a failed save.
- `PitstopTests/Persistence/SchemaV3MigrationTests.swift`: a store written by a
  V2-only container and one written by a V1-only container open under V3 with
  the car, reading, policy, completion, note and (V2) question state intact,
  and accept and keep a planned date across another reopen; the plan chains
  V1 to V2 to V3.
- `PitstopTests/Persistence/PersistenceSchemaTests.swift`: V2 pinned; V3 is V2
  plus exactly the planned record with no insurer or policy field; the app
  opens V3.
- `PitstopTests/Road/PlannedEventViewModelTests.swift`: add, label
  normalisation, second insurance refused, date and label failures, the
  picker range, edit, delete with confirmation and cancel, delete and save
  failures, the Car Board tile equal to the Road screen, and an expired date
  gone from Road.
- Independent review (separate agent, 2026-09-22): one medium and four low
  findings. Fixed: whole days left for a planned date (medium); Cancel and
  swipe-to-dismiss disabled while a save runs; the failure alert keeps its
  title while closing; the delete dialog message names the day. Recorded, not
  fixed: the time-zone shift and the grace boundary (see Consequences).
- Simulator smoke, 2026-09-22, en, DEBUG demo data: the demo insurance expiry
  on the Car Board Road tile and the Road list; "Add a date" opened the editor
  with "Other date" preselected because an expiry is on Road; a date named
  "Winter tyres" saved for today appeared as due; the row menu offered Edit and
  Delete date; the dialog named "Winter tyres" and deleting it removed the row.
- Not verified on screen: editing, VoiceOver custom actions, and the ru and uk
  strings.
