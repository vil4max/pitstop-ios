# Stop Tracking an Operation

**Status:** Accepted for implementation (agent decision under owner delegation,
2026-09-22); owner review pending\
**Task:** MNT-POL-001\
**Builds on:** [`0010-maintenance-engine-rules.md`](0010-maintenance-engine-rules.md)
(Service actions), [`0020-maintenance-anchor-closure.md`](0020-maintenance-anchor-closure.md)
(policy source separation), [`0007-persistence.md`](0007-persistence.md)
(command-only store); confirmation follows core P1 (stored data can be
corrected) and the undo-confirmation pattern of ADR 0010\
**Contracts:** [`../requirements/maintenance-engine.md`](../requirements/maintenance-engine.md)
(REQ-MAINT-023, REQ-MAINT-024, proposed),
[`../requirements/domain-model.md`](../requirements/domain-model.md) (REQ-DOMAIN-006)

## Context

Service lets the owner track an operation, change its interval, mark it done
and undo the newest "done" (ADR 0010). Nothing let the owner take a tracked
operation back. A wrong pick stayed on Service and Road for good, which breaks
core P1 (stored data can be corrected), and the planned "Track several" starter
(MNT-PRE-001) depends on a way out (MNT-INT-001, area 2).

A tracked operation is a `MaintenancePolicy` row. Its completions are separate
records, and History events are a third kind. Completions and events describe
work that was actually performed (core C5). Stopping tracking is a change of
intent, not a claim that the work did not happen.

## Decision

1. **One user-only command.** `DomainCommand.stopTrackingOperation`
   (`StopTrackingOperationCommand`: vehicle ID and operation ID). No proposal
   maps to it, so Remember and Siri cannot issue it; like
   `revokeMaintenanceCompletion`, only a Service action does.
2. **Validation.** The command rejects a blank operation ID
   (`DomainCommandError.emptyOperationID`). The store requires the current
   vehicle (`unknownVehicle` otherwise) and an owner-set policy for that
   operation (`CarMemoryStoreError.unknownPolicy` otherwise). A rejected
   command saves nothing.
3. **Owner policies only.** The store deletes the `userCustom` row for the
   vehicle and operation and returns it as `CommandResult.trackingStopped`.
   A `defaultRecommendation` or `vehicleCondition` row is never touched
   (REQ-DOMAIN-006). Service shows "Stop tracking" only when the effective
   policy is `userCustom`, and the view model ignores a request for any other
   operation. A stored row whose source this version does not recognise now
   maps to `defaultRecommendation` (it mapped to `userCustom` before), so it is
   never offered for stopping, never outranks the owner's own rule, and is not
   deleted by a command that cannot tell what it is.
4. **History stays.** Completions and History events are kept. Every surface
   recomputes from the store on reload and nothing derived is stored
   (ADR 0010). With no other policy left, the operation leaves Service, the
   Service tile and Road, the Pit mileage question stops counting it, and it
   returns to the Track list. With a recommendation or vehicle-condition
   policy left, that policy becomes effective and the operation stays on
   Service under it. No such data ships today (ADR 0020), so in practice the
   operation leaves. If the owner tracks it again, its cycle resumes from the
   kept completions, not from unknown.
5. **Confirmation that names the operation.** "Stop tracking" sits in the
   operation's "More" menu next to "Undo the last done". It opens a
   confirmation dialog titled with the operation name ("Stop tracking Engine
   oil service?"). The message says the interval is removed, History and
   "done" records stay, and the operation can be tracked again. Cancel changes
   nothing. When another policy remains, a separate message says the
   recommended interval applies instead; the view model chooses it
   (`StopTrackingRequest.fallsBackToOtherPolicy`). The pending request lives
   in `ServiceViewState.stopTrackingCandidate`, so the confirmation path is
   unit-tested in the view model. The destructive button and the title use
   the request the dialog presented, because dismissing the dialog can clear
   the pending request before the save task runs or the dialog finishes
   animating out.
6. **No undo action.** The dialog is the safeguard. Tracking the operation
   again with the same interval restores the same state, because the anchors
   derive from the kept completions. An undo banner would need to keep the
   removed policy in view state and add a timed control for a rare action.
7. **No schema change and no analytics.** The row is deleted, so the schema
   stays at V2. No analytics event exists for maintenance policies (ADR 0021),
   so none is added.
8. **Failure.** A failed save is shown on the list ("not saved"), like a failed
   undo, and the operation stays tracked.

## Consequences

- MNT-PRE-001 can now let the owner remove a wrong pick.
- A tracked operation outside the catalog can be stopped. It does not return
  to the Track list, which offers catalog operations only.
- The fallback message says "recommended interval" also for a
  vehicle-condition rule; no such rule exists yet, and the copy is reviewed
  when one is added.
- Completions of an untracked operation still appear in the History timeline
  and still count as mileage observations (ADR 0010), because they are facts.

## Rejected alternatives

- **Delete the operation's completions with the policy.** Performed work
  would disappear from History, and re-tracking would restart from unknown.
  This contradicts core C5 and REQ-DOMAIN-007.
- **Soft delete (an `isTracked` flag on the policy).** It needs a schema
  version and a migration test, and it adds a hidden state that every reader
  must filter. Deleting the row gives the same behaviour with no schema change.
- **Let the command also remove a recommendation.** A recommendation is
  source data, not the owner's choice. Hiding it needs its own decision once a
  verified source exists (ADR 0020, question B).
- **An undo banner after stopping.** See decision 6.
- **A swipe action on the row.** Rows are cards in a scroll view, not a
  `List`. The existing "More" menu already holds the other corrections.

## Verification

- `PitstopTests/Capture/DomainCommandTests.swift`: blank operation ID
  rejected, a valid command passes.
- `PitstopTests/Persistence/SwiftDataStopTrackingTests.swift`: on disk, only
  the owner's row is removed and the recommendation, other policies,
  completions and events survive a reopen. Unknown policy, recommendation-only
  operation and unknown vehicle are rejected with nothing saved. Another
  vehicle's policy for the same operation survives, and a row with an
  unrecognised source reads as a recommendation and cannot be stopped.
- `PitstopTests/Maintenance/StopTrackingTests.swift`: confirmation needed and
  cancel changes nothing, history kept, operation back in Track, re-tracking
  resumes from the kept completion, recommendation not offered, the fallback
  message and the operation staying under a kept recommendation, failure
  reported on the list, and Car Board, Road and the Pit mileage question
  after reload.
- Not verified on screen: the menu item and the dialog in en, ru and uk.
