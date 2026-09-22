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

    /// "Track several" offers only what is known to be untracked; before a successful load every operation would
    /// look untracked and a save could silently replace the owner's interval (REQ-MAINT-025, ADR 0033).
    var canTrackSeveral: Bool {
        hasLoaded && !isLoadFailed && !untrackedOperations.isEmpty
    }

    var untrackedOperations: [MaintenanceOperationID] {
        let tracked = Set(operations.map(\.id))
        return MaintenanceOperationID.catalog.filter { !tracked.contains($0) }
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
}

@MainActor
@Observable
final class ServiceViewModel {
    private(set) var state = ServiceViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date

    init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    func load() async {
        do {
            let completions = try await store.maintenanceCompletions()
            let context = try await MaintenanceContext(
                now: now(),
                latestReading: store.odometerReadings().latest,
                completions: completions
            )
            let policies = try await store.maintenancePolicies()
            let states = MaintenanceEngine().states(policies: policies, completions: completions, context: context)
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

    /// Called only after the user confirmed the work was actually performed (core C5).
    func confirmDone(_ operation: MaintenanceOperationID, on date: Date, odometerText: String) async -> Bool {
        let odometer = InputParsing.kilometers(from: odometerText)
        if case .invalid = odometer {
            return fail(.invalidOdometer)
        }
        guard DomainCommandLimits.isNotFuture(date, now: now()) else { return fail(.futureDate) }
        let odometerKm = odometer.intValue
        return await execute { vehicleID in
            .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: operation,
                performedAt: date,
                odometerKm: odometerKm
            )))
        }
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
        guard operation.policy.source == .userCustom else { return }
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

    private func execute(_ makeCommand: (VehicleID) -> DomainCommand) async -> Bool {
        do {
            let vehicleID = try await store.currentVehicle().id
            try await store.execute(makeCommand(vehicleID), now: now())
        } catch {
            return fail(.notSaved)
        }
        await load()
        state.failure = nil
        return true
    }

    private func fail(_ failure: ServiceFailure) -> Bool {
        state.failure = failure
        return false
    }
}
