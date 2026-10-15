import Foundation
import Observation

@MainActor
@Observable
final class ServiceViewModel {
    private(set) var state = ServiceViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date
    /// Day boundaries: the same-day odometer prefill and Mark as done's recheck.
    private let calendar: Calendar
    /// The open Mark as done sheet and its operation's completions when it opened (the ADR 0035 pattern).
    private var markDoneOpening: MarkDoneOpening?
    /// Which Mark as done sheet is open; nil once it closed. A save still running after its own sheet closed, or after
    /// another one opened, must not write that sheet's snapshot or message, so it compares this with the sheet it
    /// started in (REQ-MAINT-050).
    private var markDoneSheet: UUID?
    /// Sheets whose confirmation is running. A second tap before the sheet's lock renders reaches `confirmDone` too,
    /// and both would pass the recheck before either writes (REQ-MAINT-041). Another sheet's save may still run.
    @ObservationIgnored private var confirmingSheets: Set<UUID?> = []

    init(
        store: any CarMemoryStore,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    func load() async {
        do {
            let completions = try await store.maintenanceCompletions()
            let reports = try await store.vehicleServiceReports()
            let readings = try await store.odometerReadings()
            let context = MaintenanceContext(
                now: now(),
                latestReading: readings.latest,
                completions: completions,
                reports: reports
            )
            let policies = try await store.maintenancePolicies()
            let states = MaintenanceEngine().states(
                policies: policies, completions: completions, reports: reports, context: context
            )
            state.defaultReportUnit = ServiceViewState.defaultReportUnit(readings: readings, reports: reports)
            let moment = now()
            state.sameDayOdometerKm = readings.latest
                .flatMap { calendar.isDate($0.recordedAt, inSameDayAs: moment) ? $0 : nil }
                .map { Int($0.valueInKilometers.rounded()) }
            state.operationsWithOtherPolicy = Set(policies.filter { $0.source != .userCustom }.map(\.operationID))
            state.operations = states.byUrgency
            state.scope = ServicePlanner().suggestedScope(for: states, context: context)
            state.mileage = context.mileage
            state.isLoadFailed = false
            state.hasLoaded = true
        } catch {
            state.isLoadFailed = true
        }
    }

    /// The owner's own cadence for one operation; calling it again for a tracked operation changes the
    /// interval. At least one interval is required.
    func track(_ operation: MaintenanceOperationID, kilometersText: String, monthsText: String) async -> Bool {
        guard let policy = OwnerInterval.policy(for: operation, kilometersText: kilometersText, monthsText: monthsText)
        else {
            return fail(.invalidInterval)
        }
        return await execute { vehicleID in .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)) }
    }

    /// What is stored for `operation` as its Mark as done sheet is about to open, so a completion recorded while the
    /// sheet is open, by Pit over it, can be told apart from the owner's own earlier ones. It is read from the store,
    /// not the last load: Siri can save while Service stays on screen without reloading. Nil when the store cannot be
    /// read. Reading changes nothing: another sheet may open meanwhile, and a read that does not open its sheet must
    /// not touch the open sheet's snapshot or message.
    func readMarkDoneOpening(_ operation: MaintenanceOperationID) async -> MarkDoneOpening? {
        do {
            let vehicleID = try await store.currentVehicle().id
            let known = try await Set(
                store.maintenanceCompletions()
                    .filter { $0.vehicleID == vehicleID && $0.operationID == operation }
                    .map(\.id))
            return MarkDoneOpening(operation: operation, completionIDs: known)
        } catch {
            return nil
        }
    }

    /// Service is about to present the Mark as done sheet with `opening`; saves are rechecked against it from now on.
    /// Returns whether the sheet may open. Without an opening (the store could not be read) it does not: a sheet with
    /// no snapshot could record Pit's work twice, and nothing has been typed yet, so the list says it did not work.
    @discardableResult
    func openMarkDone(_ opening: MarkDoneOpening?) -> Bool {
        guard let opening else {
            state.listFailure = .notSaved
            return false
        }
        markDoneOpening = opening
        markDoneSheet = UUID()
        state.markDoneConflict = nil
        return true
    }

    /// The Mark as done sheet closed: by Cancel, a swipe or its own save. A save still running from it reports on the
    /// list from now on.
    func markDoneClosed() {
        markDoneOpening = nil
        markDoneSheet = nil
    }

    /// The owner changed the date or the odometer: the prompt about Pit's entry spoke of the previous entry
    /// (REQ-MAINT-044).
    func markDoneInputChanged() {
        state.markDoneConflict = nil
    }

    /// Called only after the user confirmed the work was actually performed (core C5). `replacingPits` is the owner's
    /// "Replace with mine" after the sheet asked about Pit's entries of the same work: what is stored is rechecked
    /// first, and only when Pit's entries within a day are still the ones the prompt showed are they revoked and the
    /// owner's completion confirmed as one command, so one store transaction (REQ-MAINT-043); otherwise the sheet asks
    /// again (REQ-MAINT-052). Returns whether the sheet closes as saved; a sheet that closed while this ran gets
    /// false, so it cannot close the sheet open now.
    func confirmDone(
        _ operation: MaintenanceOperationID,
        on date: Date,
        odometerText: String,
        replacingPits: Bool = false
    ) async -> Bool {
        // Everything after the first await checks that this sheet is still the open one: Cancel and a swipe close it
        // while it saves, and another Mark as done may open before the save returns (REQ-MAINT-050).
        let sheet = markDoneSheet
        guard confirmingSheets.insert(sheet).inserted else {
            return false
        }
        defer { confirmingSheets.remove(sheet) }
        let odometer = InputParsing.kilometers(from: odometerText)
        if case .invalid = odometer {
            return fail(.invalidOdometer)
        }
        guard DomainCommandLimits.isNotFuture(date, now: now()) else { return fail(.futureDate) }
        let odometerKm = odometer.intValue
        let prompted = replacingPits ? state.markDoneConflict.map { Set($0.pitEntries.map(\.id)) } : nil
        // Pit can record this work while the sheet is open (REQ-PIT-026), so what is stored is checked again now. Only
        // a completion recorded since the sheet opened counts: the owner's own earlier ones, even from the same day,
        // do not (REQ-MAINT-046). The same work is never recorded twice, and what the owner typed is dropped only by
        // their own choice (REQ-MAINT-040).
        let recorded: [MaintenanceCompletion]
        do {
            recorded = try await completionsRecorded(operation, since: markDoneOpening)
        } catch {
            return failMarkDone(startedIn: sheet)
        }
        let replaced: Set<UUID>
        switch MarkDoneRecheck(
            recorded: recorded, date: date, odometerKm: odometerKm, replacing: prompted, calendar: calendar
        ) {
        case .write:
            replaced = []
        case .alreadyRecorded:
            // The same work on the same date, and nothing typed here that it lacks.
            let isOpen = markDoneSheet == sheet
            if isOpen {
                markDoneOpening = nil
            }
            await load()
            guard isOpen, markDoneSheet == sheet else { return false }
            state.failure = nil
            state.markDoneConflict = nil
            return true
        case let .replace(ids):
            // The owner chose their entry over exactly these: the choice stands even if the app closed the sheet
            // meanwhile.
            replaced = ids
        case let .conflict(entries):
            // Only the open sheet can ask. Once it closed, Pit's entry is kept and the owner's is not recorded; the
            // reloaded list shows Pit's record and says why (REQ-MAINT-049).
            guard markDoneSheet == sheet else {
                await load()
                state.listFailure = .pitAlreadyRecorded
                return false
            }
            state.failure = nil
            state.markDoneConflict = MarkDoneConflict(pitEntries: entries)
            state.markDoneConflictNotices += 1
            return false
        }
        let saved = await write { vehicleID in
            let completion = MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: operation,
                performedAt: date,
                odometerKm: odometerKm
            )
            return replaced.isEmpty
                ? .confirmMaintenanceCompletion(.init(completion: completion))
                : .replaceMaintenanceCompletion(.init(replacedIDs: replaced, completion: completion))
        }
        guard saved else { return failMarkDone(startedIn: sheet) }
        // A closed sheet's work is on the reloaded list; the sheet open now keeps its snapshot and message.
        guard markDoneSheet == sheet else { return false }
        markDoneOpening = nil
        state.failure = nil
        state.markDoneConflict = nil
        return true
    }

    /// "Keep Pit's entry": nothing from the sheet is recorded, and the list reloads to show Pit's entry
    /// (REQ-MAINT-042). The sheet's save lock keeps it the open one until this returns; false if another sheet is
    /// open by then.
    func keepPitsEntry() async -> Bool {
        let sheet = markDoneSheet
        markDoneOpening = nil
        state.failure = nil
        state.markDoneConflict = nil
        await load()
        return markDoneSheet == sheet
    }

    /// Takes back the latest confirmation of an operation, for a tap or a number entered by mistake.
    func undoLastCompletion(of operation: MaintenanceOperationState) async -> Bool {
        guard let completion = operation.lastCompletion else { return true }
        let undone = await execute { _ in .revokeMaintenanceCompletion(.init(completionID: completion.id)) }
        if !undone {
            // `execute` reported into the sheet channel; this action has no sheet.
            state.failure = nil
            state.listFailure = .notSaved
        }
        return undone
    }

    /// Only the owner's own policy can be removed; a recommendation-backed operation has no such action.
    func requestStopTracking(_ operation: MaintenanceOperationState) {
        guard operation.policy?.source == .userCustom else { return }
        state.stopTrackingCandidate = StopTrackingRequest(
            operation: operation.id,
            fallsBackToOtherPolicy: state.operationsWithOtherPolicy.contains(operation.id)
        )
    }

    func cancelStopTracking() {
        state.stopTrackingCandidate = nil
    }

    /// The dialog's destructive action. It takes the operation the dialog presented rather than reading the
    /// pending request, because dismissing the dialog can clear that request before this task runs.
    /// History stays; the operation returns to the Track list unless another rule still applies.
    func confirmStopTracking(_ operation: MaintenanceOperationID) async -> Bool {
        state.stopTrackingCandidate = nil
        let stopped = await execute { vehicleID in
            .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: operation))
        }
        if !stopped {
            // Like undo, this action has no sheet, so the failure belongs on the list.
            state.failure = nil
            state.listFailure = .notSaved
        }
        return stopped
    }

    /// A fresh starter for the operations not tracked yet; after it saves anything, Service reloads (ADR 0033).
    func makeTrackSeveral() -> TrackSeveralViewModel {
        TrackSeveralViewModel(
            store: store,
            operations: state.untrackedOperations,
            now: now,
            onSaved: { [weak self] in await self?.load() }
        )
    }

    func dismissFailure() {
        state.failure = nil
        state.listFailure = nil
    }

    /// Completions of `operation` stored since its Mark as done sheet opened; none without an open sheet for it.
    private func completionsRecorded(
        _ operation: MaintenanceOperationID,
        since opening: MarkDoneOpening?
    ) async throws -> [MaintenanceCompletion] {
        guard let opening, opening.operation == operation else { return [] }
        let vehicleID = try await store.currentVehicle().id
        return try await store.maintenanceCompletions().filter { completion in
            completion.vehicleID == vehicleID && completion.operationID == operation
                && !opening.completionIDs.contains(completion.id)
        }
    }

    /// A Mark as done save that was not recorded says so in its sheet while that sheet is open, and on the list once
    /// it closed: the sheet open now, if any, is about other work.
    private func failMarkDone(startedIn sheet: UUID?) -> Bool {
        guard markDoneSheet == sheet else {
            state.listFailure = .notSaved
            return false
        }
        return fail(.notSaved)
    }

    private func execute(_ makeCommand: (VehicleID) -> DomainCommand) async -> Bool {
        guard await write(makeCommand) else { return fail(.notSaved) }
        state.failure = nil
        return true
    }

    /// Stores the command and reloads; where a failure is shown is the caller's choice.
    private func write(_ makeCommand: (VehicleID) -> DomainCommand) async -> Bool {
        do {
            let vehicleID = try await store.currentVehicle().id
            try await store.execute(makeCommand(vehicleID), now: now())
        } catch {
            return false
        }
        await load()
        return true
    }

    private func fail(_ failure: ServiceFailure) -> Bool {
        state.failure = failure
        return false
    }
}

// MARK: - Dashboard reading

extension ServiceViewModel {
    /// The owner enters what the car's display says is left (ADR 0035). The value is kept in the unit
    /// the owner chose; the odometer is required with a distance. Nothing is written when a check fails.
    func enterReport(
        _ operation: MaintenanceOperationID,
        distanceText: String,
        unit: DistanceUnit,
        daysText: String,
        odometerText: String
    ) async -> Bool {
        let distance = WholeNumberInput.parseSigned(distanceText, upTo: 1_000_000)
        let days = WholeNumberInput.parseSigned(daysText, upTo: 100_000)
        guard distance != .invalid, days != .invalid, distance != .absent || days != .absent else {
            return fail(.invalidReport)
        }
        let odometer = InputParsing.kilometers(from: odometerText)
        if case .invalid = odometer {
            return fail(.invalidOdometer)
        }
        if distance != .absent, odometer.intValue == nil {
            return fail(.reportOdometerMissing)
        }
        let moment = now()
        let odometerKm = odometer.intValue
        do {
            let vehicleID = try await store.currentVehicle().id
            let report = VehicleServiceReport(
                vehicleID: vehicleID, operationID: operation, reportedAt: moment, odometerKm: odometerKm,
                remainingDistance: distance.intValue.map(Double.init), distanceUnit: unit,
                remainingDays: days.intValue, source: .manualEntry
            )
            try await store.execute(.recordVehicleServiceReport(.init(report: report)), now: moment)
        } catch .invalidCommand(.reportRemainingDistanceOutOfRange) {
            return fail(.invalidReport)
        } catch .invalidCommand(.reportRemainingDaysOutOfRange) {
            return fail(.invalidReport)
        } catch .invalidCommand(.odometerOutOfRange) {
            return fail(.invalidOdometer)
        } catch {
            return fail(.notSaved)
        }
        await load()
        state.failure = nil
        return true
    }

    func requestDeleteReport(_ operation: MaintenanceOperationState) {
        guard operation.report != nil else { return }
        state.deleteReportCandidate = operation.id
    }

    func cancelDeleteReport() {
        state.deleteReportCandidate = nil
    }

    /// The dialog's destructive action; it takes the operation the dialog presented (the ADR 0031
    /// pattern). Completions, History and the owner's interval stay.
    func confirmDeleteReport(_ operation: MaintenanceOperationID) async -> Bool {
        state.deleteReportCandidate = nil
        let deleted = await execute { vehicleID in
            .removeVehicleServiceReport(.init(vehicleID: vehicleID, operationID: operation))
        }
        if !deleted {
            state.failure = nil
            state.listFailure = .notSaved
        }
        return deleted
    }
}
