import Foundation
import Observation

struct CarBoardViewState: Equatable {
    var car: ProvisionalCarContext = .firstLaunch
    var mileage: CarBoardMileage = .unknown
    var notes: NotesSummary = .empty
    var history: HistoryTimeline = .empty
    /// Most urgent first; empty when nothing is tracked.
    var service: [MaintenanceOperationState] = []
    var road: RoadProjection?
    var isStorageTemporary = false
    /// Kept apart from `failure` so dismissing a save alert can never hide the retry row.
    var isLoadFailed = false
    var failure: CarBoardFailure?
}

enum CarBoardFailure: Equatable {
    case saveFailed
    /// The name was saved but the reading was not; the message must not claim nothing changed.
    case mileageNotSaved
    case invalidOdometer
}

@MainActor
@Observable
final class CarBoardViewModel {
    private(set) var state: CarBoardViewState

    private let store: any CarMemoryStore
    private let analytics: any AnalyticsTracking<OdometerAnalyticsEvent>
    private let now: @Sendable () -> Date
    /// The owner's calendar, passed to the Road projection so the tile and the Road screen bucket
    /// reading days the same way (ADR 0034).
    private let calendar: Calendar
    private var vehicleID: VehicleID?
    /// Whether the shown mileage is recent enough to count; a stale one is re-recorded even unchanged.
    private var isMileageCurrent = false

    init(
        store: any CarMemoryStore,
        persistence: PersistenceMode = .durable,
        analytics: any AnalyticsTracking<OdometerAnalyticsEvent> = NoAnalyticsTracker(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.analytics = analytics
        self.now = now
        self.calendar = calendar
        state = CarBoardViewState(isStorageTemporary: persistence == .temporary)
    }

    func load() async {
        // One moment for every projection on the board, so they cannot disagree with each other.
        let moment = now()
        do {
            let vehicle = try await store.currentVehicle()
            let readings = try await store.odometerReadings()
            let latest = readings.latest
            let completions = try await store.maintenanceCompletions()
            // The header and Service read mileage from one context, so they cannot disagree
            // (REQ-BOARD-026, ADR 0010).
            let context = MaintenanceContext(now: moment, latestReading: latest, completions: completions)
            vehicleID = vehicle.id
            isMileageCurrent = context.mileage == .known
            state.car = ProvisionalCarContext(vehicle: vehicle, observedKm: context.observedKm)
            state.mileage = CarBoardMileage(odometerKm: state.car.odometerKm)
            state.notes = try await NotesSummary(notes: store.notes())
            state.history = try await HistoryTimeline(events: store.historyEvents(), completions: completions)
            state.service = try await MaintenanceEngine().states(
                policies: store.maintenancePolicies(),
                completions: completions,
                context: context
            ).byUrgency
            // The tile projects the same planned dates as the Road screen; insurance has no tile of its own
            // (ADR 0032).
            state.road = try await RoadProjector().project(RoadContext(
                now: moment,
                maintenanceStates: state.service,
                plannedEvents: store.plannedEvents().map(\.roadEvent),
                history: state.history,
                mileageObservations: MileageObservation.history(readings: readings, completions: completions),
                calendar: calendar
            ))
            state.isLoadFailed = false
        } catch {
            // The last known state stays on screen; Car Board never becomes an error page.
            state.isLoadFailed = true
        }
    }

    /// Returns `true` when the edit was saved, so the editor closes only after persistence succeeded.
    /// A blank name means "leave it as it is": the editor may have been opened over stale state, and
    /// a placeholder must never be written back as a user-supplied fact (core C2).
    func saveCar(name: String, odometerText: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let kilometers = InputParsing.kilometers(from: odometerText)
        if case .invalid = kilometers {
            return fail(.invalidOdometer)
        }
        // An earlier load may have failed; without the car there is nothing to attach the edit to.
        if vehicleID == nil {
            await load()
        }
        guard let vehicleID else { return fail(.saveFailed) }

        var nameWasSaved = false
        do {
            if !trimmedName.isEmpty, trimmedName != state.car.name {
                let fact = VehicleFact(field: .name, value: trimmedName)
                try await store.execute(.recordVehicleFact(.init(vehicleID: vehicleID, fact: fact)), now: now())
                nameWasSaved = true
            }
            // The same number is still worth recording when the shown mileage is stale: it tells the
            // engine where the car is today (REQ-BOARD-026).
            if case let .value(value) = kilometers, value != state.car.odometerKm || !isMileageCurrent {
                let reading = OdometerReading(vehicleID: vehicleID, value: Double(value), recordedAt: now())
                try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now())
                analytics.track(.odometerUpdated(source: .explicit, anomalyConfirmation: .noAnomaly))
            }
        } catch {
            await load()
            return fail(nameWasSaved ? .mileageNotSaved : .saveFailed)
        }
        await load()
        // A stale failure from an earlier attempt must not outlive a successful save.
        state.failure = nil
        return true
    }

    func dismissFailure() {
        state.failure = nil
    }

    private func fail(_ failure: CarBoardFailure) -> Bool {
        state.failure = failure
        return false
    }
}
