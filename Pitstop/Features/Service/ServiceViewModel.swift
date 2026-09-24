import Foundation
import Observation

struct ServiceViewState: Equatable {
    var operations: [MaintenanceOperationState] = []
    var scope: SuggestedServiceScope = .empty
    var mileage: MileageKnowledge = .unknown
    var isLoadFailed = false
    /// False until the first successful load; before it, `operations` is empty only because nothing was read.
    var hasLoaded = false
    /// Shown inside the open sheet, next to the input that failed.
    var failure: ServiceFailure?
    /// Shown on the list: undo happens with no sheet open.
    var listFailure: ServiceFailure?
    /// Stopping tracking waits for an explicit confirmation that names the operation, as undo does
    /// (core P1, ADR 0010, ADR 0031).
    var stopTrackingCandidate: StopTrackingRequest?
    /// Operations that keep a rule the owner did not set; stopping the owner's rule falls back to it.
    var operationsWithOtherPolicy: Set<MaintenanceOperationID> = []
    /// Deleting a dashboard reading waits for a confirmation that names the operation (ADR 0035).
    var deleteReportCandidate: MaintenanceOperationID?
    /// The unit the dashboard sheet starts with: the newest reading's unit, so a car in miles is not
    /// entered as kilometres by default (REQ-MAINT-037).
    var defaultReportUnit: DistanceUnit = .kilometers
    /// Today's odometer reading, if one exists: the dashboard sheet prefills it (ADR 0035). An older
    /// reading is not offered, because the car has moved since.
    var sameDayOdometerKm: Int?
    /// The open Mark as done sheet's input differs from what Pit recorded for the same work and date while the
    /// sheet was open. The sheet stays open and says so; only "Save anyway" records it (REQ-PIT-026).
    var isMarkDoneAlreadyRecorded = false
    /// Grows each time the sheet has to say so, so it is announced to VoiceOver even when the message is already
    /// shown: focus stays on the confirmation, and the message appears below it.
    var markDoneAlreadyRecordedNotices = 0

    /// Only operations tracked by a rule count here: one kept on Service by a dashboard reading alone can
    /// still be tracked with the owner's own interval.
    var untrackedOperations: [MaintenanceOperationID] {
        let tracked = Set(operations.filter { $0.policy != nil }.map(\.id))
        return MaintenanceOperationID.catalog.filter { !tracked.contains($0) }
    }

    /// "Track several" offers only what is known to be untracked; before a successful load every operation would
    /// look untracked and a save could silently replace the owner's interval (REQ-MAINT-025, ADR 0033).
    var canTrackSeveral: Bool {
        hasLoaded && !isLoadFailed && !untrackedOperations.isEmpty
    }

    /// "Track an operation" needs something left to track (the delivered rule).
    var canTrackOne: Bool {
        !untrackedOperations.isEmpty
    }

    /// The one "Track" toolbar menu (redesign proposal §4, decision 4) stays available while either item is, so
    /// "Track several" waiting for the first load reads as a disabled item rather than a missing control. That is
    /// `canTrackOne` alone: "Track several" also needs something untracked, so it is never enabled without it.
    var isTrackMenuEnabled: Bool {
        canTrackOne
    }
}

/// An open Mark as done sheet: its operation and the completions stored for it when it opened.
struct MarkDoneOpening: Equatable {
    let operation: MaintenanceOperationID
    let completionIDs: Set<UUID>
}

/// What Mark as done does when completions of its operation were recorded while the sheet was open (REQ-PIT-026).
enum MarkDoneRecheck: Equatable {
    /// Nothing recorded for this date: the owner's completion is new work and is written.
    case write
    /// The same work on the same date, and the typed odometer is empty or the one recorded: writing would duplicate.
    case alreadyRecorded
    /// The same work on the same date, but the typed odometer differs or the recorded one has none: writing would
    /// duplicate and skipping would drop the input, so the owner decides.
    case askOwner

    init(recorded: [MaintenanceCompletion], date: Date, odometerKm: Int?, calendar: Calendar = .current) {
        let sameDate = recorded.filter { calendar.isDate($0.performedAt, inSameDayAs: date) }
        if sameDate.isEmpty {
            self = .write
        } else if odometerKm == nil || sameDate.contains(where: { $0.odometerKm == odometerKm }) {
            self = .alreadyRecorded
        } else {
            self = .askOwner
        }
    }
}

/// What the confirmation must say: with another rule left, the operation stays on Service under that rule.
struct StopTrackingRequest: Equatable {
    let operation: MaintenanceOperationID
    let fallsBackToOtherPolicy: Bool
}

enum ServiceFailure: Equatable {
    case notSaved
    case invalidInterval
    case invalidOdometer
    case futureDate
    /// The dashboard reading has neither a distance nor a number of days, or one of them is out of range.
    case invalidReport
    /// A reported distance needs the mileage it was read at.
    case reportOdometerMissing
}

@MainActor
@Observable
final class ServiceViewModel {
    private(set) var state = ServiceViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date
    /// The open Mark as done sheet and its operation's completions when it opened (the ADR 0035 pattern).
    private var markDoneOpening: MarkDoneOpening?
    /// Which Mark as done sheet is open; nil once it closed. A save still running after its own sheet closed, or after
    /// another one opened, must not write that sheet's snapshot or message, so it compares this with the sheet it
    /// started in (REQ-MAINT-040).
    private var markDoneSheet: UUID?

    init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
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
            state.defaultReportUnit = Self.defaultUnit(readings: readings, reports: reports)
            let moment = now()
            state.sameDayOdometerKm = readings.latest
                .flatMap { Calendar.current.isDate($0.recordedAt, inSameDayAs: moment) ? $0 : nil }
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
            let known = try await Set(store.maintenanceCompletions()
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
        state.isMarkDoneAlreadyRecorded = false
        return true
    }

    /// The Mark as done sheet closed: by Cancel, a swipe or its own save. A save still running from it reports on the
    /// list from now on.
    func markDoneClosed() {
        markDoneOpening = nil
        markDoneSheet = nil
    }

    /// The owner changed the date or the odometer: the "already saved" message spoke of the previous entry.
    func markDoneInputChanged() {
        state.isMarkDoneAlreadyRecorded = false
    }

    /// Called only after the user confirmed the work was actually performed (core C5). `anyway` is the owner's
    /// "Save anyway" after the sheet said Pit already recorded this work for the date; the entry is still
    /// rechecked, because it may have been edited to match what Pit stored. Returns whether the sheet closes as saved;
    /// a sheet that closed while this ran gets false, so it cannot close the sheet open now.
    func confirmDone(
        _ operation: MaintenanceOperationID,
        on date: Date,
        odometerText: String,
        anyway: Bool = false
    ) async -> Bool {
        let odometer = InputParsing.kilometers(from: odometerText)
        if case .invalid = odometer {
            return fail(.invalidOdometer)
        }
        guard DomainCommandLimits.isNotFuture(date, now: now()) else { return fail(.futureDate) }
        let odometerKm = odometer.intValue
        // Everything after the first await checks that this sheet is still the open one: Cancel and a swipe close it
        // while it saves, and another Mark as done may open before the save returns (REQ-MAINT-040).
        let sheet = markDoneSheet
        // Pit can record this work while the sheet is open (REQ-PIT-026), so what is stored is checked again now. Only
        // a completion recorded since the sheet opened counts: the owner's own earlier ones, even from the same day,
        // do not (REQ-MAINT-031). What the owner typed is never dropped without a word (REQ-MAINT-040, proposed).
        let recorded: [MaintenanceCompletion]
        do {
            recorded = try await completionsRecorded(operation, since: markDoneOpening)
        } catch {
            return failMarkDone(startedIn: sheet)
        }
        switch MarkDoneRecheck(recorded: recorded, date: date, odometerKm: odometerKm) {
        case .write:
            break
        case .alreadyRecorded:
            // The same work on the same date, and nothing typed here that it lacks.
            let isOpen = markDoneSheet == sheet
            if isOpen {
                markDoneOpening = nil
            }
            await load()
            guard isOpen, markDoneSheet == sheet else { return false }
            state.failure = nil
            state.isMarkDoneAlreadyRecorded = false
            return true
        case .askOwner where anyway:
            break
        case .askOwner:
            // Only the open sheet can ask; once it closed, the owner's entry is not recorded and the list says so.
            guard markDoneSheet == sheet else { return failMarkDone(startedIn: sheet) }
            state.failure = nil
            state.isMarkDoneAlreadyRecorded = true
            state.markDoneAlreadyRecordedNotices += 1
            return false
        }
        let saved = await write { vehicleID in
            .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: operation,
                performedAt: date,
                odometerKm: odometerKm
            )))
        }
        guard saved else { return failMarkDone(startedIn: sheet) }
        // A closed sheet's work is on the reloaded list; the sheet open now keeps its snapshot and message.
        guard markDoneSheet == sheet else { return false }
        markDoneOpening = nil
        state.failure = nil
        state.isMarkDoneAlreadyRecorded = false
        return true
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

    // MARK: - Dashboard reading

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
        var saved = false
        do {
            let vehicleID = try await store.currentVehicle().id
            let report = VehicleServiceReport(
                vehicleID: vehicleID, operationID: operation, reportedAt: moment, odometerKm: odometerKm,
                remainingDistance: distance.intValue.map(Double.init), distanceUnit: unit,
                remainingDays: days.intValue, source: .manualEntry
            )
            try await store.execute(.recordVehicleServiceReport(.init(report: report)), now: moment)
            saved = true
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
        return saved
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

    private static func defaultUnit(readings: [OdometerReading], reports: [VehicleServiceReport]) -> DistanceUnit {
        let newestReport = reports.filter { $0.remainingDistance != nil }.max { $0.reportedAt < $1.reportedAt }
        if let newestReport, newestReport.reportedAt >= (readings.latest?.recordedAt ?? .distantPast) {
            return newestReport.distanceUnit
        }
        return readings.latest?.unit ?? .kilometers
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
