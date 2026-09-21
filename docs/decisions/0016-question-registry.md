# Question Registry and Persisted Question State

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-21); owner review pending\
**Task:** DISC-001\
**Contracts:** [`../requirements/pit-behavior-and-motion.md`](../requirements/pit-behavior-and-motion.md)
(REQ-PIT-008, 009, 010, 012), core C2 and C3,
[`0012-pit-presence-and-attention.md`](0012-pit-presence-and-attention.md),
[`0007-persistence.md`](0007-persistence.md)

## Context

ADR 0012 gave Pit an attention policy that takes a list of `PitQuestion`
values and two elapsed times, but nothing produced either. `PitQuestion.unlocks`
is optional, so "a question requires a declared value unlock" (REQ-PIT-009) was
only a runtime filter, and nothing recorded what happens when the user says
"not now". The card asks that every discovery question document the value it
unlocks and its deferral path, and ADR 0012 left persisted question state to
this task.

## Decision

### A question is declared in code, and the declaration is complete by construction

`PitQuestionDefinition` carries a stable ID, the surface it belongs to
(`VisibleFeature`), a priority, a `PitQuestionValue` and a `PitDeferralPath`.
Both are non-optional, so a question without them does not compile.

- `PitQuestionValue` is the `PitValueUnlock` category plus a `claim`: the
  observable change an answer makes, written so beta evidence can confirm or
  refute it (the contract's analytics question "Does a Pit answer unlock
  Road/Service value?").
- `PitDeferralPath` says when the question may return after a deferral and
  after a dismissal (`never` or `notBefore(interval)`, measured from the
  resolution time), and `withoutAnswer`: what the app does while the answer is
  missing. Core C2 applies, so the fact stays unknown rather than defaulted.

`PitQuestionRegistry` is the only source of questions. Its initializer rejects
a blank ID, a duplicate ID (state is keyed by it), a blank value claim, a blank
fallback, and a non-positive return interval. Free text cannot be checked by
the compiler, so the product list `productDefinitions` is built by a test; an
invalid entry fails `just verify` instead of a launch.

The product list is empty. DISC-002 adds the first question. Tests use
fixture questions from `PitstopTests/Fixtures/PitQuestionFixtures.swift`.

### State is persisted per question; the budget is derived

`PitQuestionState` stores, per question ID, the resolution, `lastAskedAt`,
`lastDismissedAt`, and `resolvedAt`. No row means unresolved. The global
budget the policy needs — last interruption, last dismissal — is
`PitAttentionBudget`, the maximum over all rows, so there is no second copy
that could disagree with the rows. `lastDismissedAt` is separate from
`resolvedAt` so a later answer cannot erase a dismissal cooldown. Any
resolution also sets `lastAskedAt` when it is still empty: a resolution implies
the question was shown, and a caller that skipped `asked` must not leave the
12-hour interruption cooldown unstarted (REQ-PIT-010).

`PitAttentionPolicy.question(registry:states:activity:context:now:)` joins the
registry with the stored state and feeds the existing policy. Rows whose ID is
no longer registered are ignored, so removing a question needs no migration.

### Writes are commands on a separate, small protocol

`PitQuestionStateStore` has one read (`questionStates()`) and one write,
`execute(_ PitQuestionCommand, now:)`, with the commands `asked`, `answered`,
`deferred`, and `dismissed`. This is the command-only style of
`CarMemoryStore`, but a separate protocol, because:

- `DomainCommand` is the write set of the Capture Pipeline (core C4). Question
  state is Pit's interaction record, not a car fact; putting it there would let
  a capture proposal mutate it and would make every `CarMemoryStore` fake grow.
- Question state has its own error space (`unknownQuestion`,
  `alreadyAnswered`).

The store validates every command against the registry it is initialised with,
so no caller can create state for an undeclared question. An answer is final:
deferring or dismissing an answered question is rejected, and a rejected or
failed write rolls back and saves nothing.

`SwiftDataPitQuestionStore` is a `ModelActor` on the same container, and so
the same file, as `SwiftDataCarMemoryStore`. It writes its initializer by hand
because it also holds the registry.

### Schema version 2

`PitstopSchemaV2` is V1 plus `PitQuestionStateRecord`, reached by a lightweight
migration stage, as ADR 0007 planned. V1 record classes are reused, not
copied: they are unchanged, and existing code keeps naming them.

Reuse makes V1 frozen. A store on disk is matched to a schema version by the
shape of its model classes, and V1 is what the `tf-1.0.0-1` and `tf-1.1.0-1`
builds wrote. Editing a V1 class — adding a field to `VehicleRecord`, say —
would leave those stores matching no version, the container would fail to
open, and the app would fall back to memory. The migration test would not
notice, because it builds "V1" from the edited class. So:

- V1 classes are never edited. A change to a record is a new schema version
  with its own copy of that class, and code moves to the copy.
- `PersistenceSchemaTests` pins V1's entities, attribute names, types,
  optionality, and uniqueness as literals captured on 2026-09-21, and checks
  that V2 is exactly V1 plus the question state entity. Any V1 change fails
  `just verify`. The
resolution is a raw string; an unreadable value reads as `deferred`, because
the safe default for a question is silence (core C3), not asking again. A test
opens a store written by a V1-only container under V2 and reads the car and
its notes back.

## Rejected alternatives

- **New cases on `DomainCommand` and reads on `CarMemoryStore`.** See above:
  it mixes interaction state into the capture write path.
- **Adding the record to `PitstopSchemaV1` in place.** A store on disk whose
  model hash matches no schema in the migration plan may fail to open; the
  migration plan exists so the second version is a stage.
- **`UserDefaults` for timestamps.** Two storage mechanisms for one feature,
  no rollback with the resolution, and no migration story (ADR 0007).
- **Storing the global last-interruption and last-dismissal times in their own
  row.** Derivable from the per-question rows, and a second copy can drift.
- **Optional `unlocks` in the definition with a runtime check.** The old
  `PitQuestion.unlocks` stays optional for the policy's own defence, but a
  definition cannot omit its value.
- **A typed enum for `withoutAnswer`.** No product question exists yet to
  justify the cases; free text validated as non-blank documents the behaviour
  without guessing the taxonomy.

## Open questions for owner review

- **Deferral return is declared, not yet enforced.** The policy still treats a
  deferred question as final (ADR 0012), which is stricter than any
  `notBefore` value. DISC-003 decides whether and when a deferred question may
  return and wires `PitDeferralPath` into the policy.
- **App wiring.** The app migrates to V2 on the next launch, but nothing
  creates `SwiftDataPitQuestionStore` or calls the policy yet. DISC-002 wires
  both with the first question; the in-memory fallback in `AppEnvironment`
  will need a question store too.
- **TestFlight downgrade.** A build with only V1 cannot open a store already
  migrated to V2, so installing an older build after this one falls back to
  memory: nothing is deleted, but car memory looks empty until the user
  upgrades again. Acceptable for TestFlight; a release policy should forbid
  downgrades or ship V2 before any build that depends on it.
- **Question ID stability.** IDs are strings chosen by the developer. Renaming
  one silently resets its state; a test that pins the product IDs may be worth
  adding once there are several.
- **Clock changes.** Elapsed times come from wall-clock dates. A timestamp in
  the future, after a clock change, blocks questions until the clock catches up;
  that is the safe direction, so it is not handled.
