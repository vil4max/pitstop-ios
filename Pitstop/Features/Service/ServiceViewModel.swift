import Foundation
import Observation

struct ServiceViewState: Equatable {
    var operations: [MaintenanceOperationState] = []
    var scope: SuggestedServiceScope = .empty
    var mileage: MileageKnowledge = .unknown
    var isLoadFailed = false
    /// Shown inside the open sheet, next to the input that failed.
    var failure: ServiceFailure?
    /// Shown on the list: undo happens with no sheet open.
    var listFailure: ServiceFailure?

    var untrackedOperations: [MaintenanceOperationID] {
        let tracked = Set(operations.map(\.id))
        return MaintenanceOperationID.catalog.filter { !tracked.contains($0) }
    }
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
            let states = try await MaintenanceEngine().states(
                policies: store.maintenancePolicies(),
                completions: completions,
                context: context
            )
            state.operations = states.byUrgency
            state.scope = ServicePlanner().suggestedScope(for: states, context: context)
            state.mileage = context.mileage
            state.isLoadFailed = false
        } catch {
            state.isLoadFailed = true
        }
    }

    /// The owner's own cadence for one operation; calling it again for a tracked operation changes the
    /// interval. At least one interval is required.
    func track(_ operation: MaintenanceOperationID, kilometersText: String, monthsText: String) async -> Bool {
        let kilometers = WholeNumberInput.parsePositive(kilometersText, upTo: 1_000_000)
        let months = WholeNumberInput.parsePositive(monthsText, upTo: 600)
        guard kilometers != .invalid, months != .invalid, kilometers.intValue != nil || months.intValue != nil else {
            return fail(.invalidInterval)
        }
        let policy = MaintenancePolicy(
            operationID: operation,
            distanceIntervalKm: kilometers.intValue,
            timeIntervalMonths: months.intValue,
            source: .userCustom
        )
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
