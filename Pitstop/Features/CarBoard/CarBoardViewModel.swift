import Foundation
import Observation

struct CarBoardViewState: Equatable {
    var car: ProvisionalCarContext = .firstLaunch
    var mileage: CarBoardMileage = .unknown
    var notes: NotesSummary = .empty
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
    private let now: @Sendable () -> Date
    private var vehicleID: VehicleID?

    init(
        store: any CarMemoryStore,
        persistence: AppEnvironment.Persistence = .durable,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.now = now
        state = CarBoardViewState(isStorageTemporary: persistence == .temporary)
    }

    func load() async {
        do {
            let vehicle = try await store.currentVehicle()
            let latest = try await store.odometerReadings().latest
            vehicleID = vehicle.id
            state.car = ProvisionalCarContext(vehicle: vehicle, latestReading: latest)
            state.mileage = CarBoardMileage(odometerKm: state.car.odometerKm)
            state.notes = try await NotesSummary(notes: store.notes())
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
        let kilometers = Self.kilometers(from: odometerText)
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
            if case let .value(value) = kilometers, value != state.car.odometerKm {
                let reading = OdometerReading(vehicleID: vehicleID, value: Double(value), recordedAt: now())
                try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now())
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

    enum OdometerInput: Equatable {
        /// Blank input means "still unknown"; it must not become a zero reading (REQ-BOARD-004).
        case absent
        case value(Int)
        case invalid
    }

    /// Plain ASCII digits, optionally grouped in threes by one kind of separator. Any other separator
    /// may be a decimal point, and dropping it would record a reading ten times too large.
    static func kilometers(from text: String) -> OdometerInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .absent }
        let grouped = /[0-9]{1,3}([ ,.\u{00A0}\u{202F}])[0-9]{3}(\1[0-9]{3})*|[0-9]+/
        guard trimmed.wholeMatch(of: grouped) != nil else { return .invalid }
        let digits = trimmed.filter { $0.isASCII && $0.isNumber }
        guard let value = Int(digits), DomainCommandLimits.isPlausibleOdometer(Double(value)) else { return .invalid }
        return .value(value)
    }
}
