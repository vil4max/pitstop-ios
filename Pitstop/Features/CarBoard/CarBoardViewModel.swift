import Foundation
import Observation

struct CarBoardViewState: Equatable {
    var car: ProvisionalCarContext = .firstLaunch
    /// The body the car is drawn as without a photo: SUV until the owner chooses (REQ-BOARD-030).
    var carBody: CarBody = .suv
    /// The photo's files on disk; nil without a photo, or when its files are gone (REQ-BOARD-029).
    var carPhoto: CarPhotoFiles?
    /// Whether a photo can be kept at all: false without the App Group container, where the editor
    /// offers no photo.
    var canStorePhoto = false
    var mileage: CarBoardMileage = .unknown
    /// The age of the observation behind `mileage`; nil exactly when no observation exists (REQ-BOARD-027).
    var mileageRecency: MileageRecency?
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
    /// Something else was saved but the body or the photo was not; again not "nothing changed".
    case profileNotSaved
    case invalidOdometer
}

/// What the car editor asks for the photo on save. Nothing is stored or deleted before the owner saves.
enum CarPhotoEdit: Equatable, Sendable {
    case unchanged
    /// The data picked in the editor, not yet decoded or bounded.
    case replace(Data)
    case remove
}

/// The car as the editor showed it when it opened. Pit can record a mileage or a name while the editor is open
/// (REQ-PIT-026) and the board reloads under it, so a save compares the draft with this, not with the reloaded
/// car: a field the owner left alone is never written back over a newer value, as Mark as done keeps what was
/// stored when its sheet opened.
struct CarEditorOpening: Equatable {
    let car: ProvisionalCarContext
    let body: CarBody
    /// Whether a photo was shown, so the editor offers to remove it.
    let hasPhoto: Bool
    /// Whether the shown mileage was recent enough to count; a stale one is re-recorded even unchanged.
    let isMileageCurrent: Bool
    /// When the shown mileage was observed; a different date at save means something newer was recorded since.
    let mileageObservedAt: Date?
}

@MainActor
@Observable
final class CarBoardViewModel {
    private(set) var state: CarBoardViewState

    private let store: any CarMemoryStore
    /// Nil when the App Group container is unavailable: the car is then drawn as its placeholder.
    private let photoPreparation: CarPhotoPreparation?
    private let analytics: any AnalyticsTracking<OdometerAnalyticsEvent>
    private let now: @Sendable () -> Date
    /// The owner's calendar, passed to the Road projection so the tile and the Road screen bucket
    /// reading days the same way (ADR 0034).
    private let calendar: Calendar
    private var vehicleID: VehicleID?
    /// The stored reference, whose files a replaced or removed photo deletes (REQ-BOARD-033).
    private var photoID: CarPhotoID?
    /// Whether the shown mileage is recent enough to count; a stale one is re-recorded even unchanged.
    private var isMileageCurrent = false
    /// When the shown mileage was observed, so an editor can tell whether a newer one arrived while it was open.
    private var mileageObservedAt: Date?

    init(
        store: any CarMemoryStore,
        persistence: PersistenceMode = .durable,
        photos: (any CarPhotoStoring)? = nil,
        lifter: (any SubjectLifter)? = nil,
        analytics: any AnalyticsTracking<OdometerAnalyticsEvent> = NoAnalyticsTracker(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        photoPreparation = photos.map { CarPhotoPreparation(photos: $0, lifter: lifter) }
        self.analytics = analytics
        self.now = now
        self.calendar = calendar
        state = CarBoardViewState(canStorePhoto: photos != nil, isStorageTemporary: persistence == .temporary)
    }

    /// What the car editor opening now shows; the editor keeps it until it closes.
    var editorOpening: CarEditorOpening {
        CarEditorOpening(
            car: state.car,
            body: state.carBody,
            hasPhoto: state.carPhoto != nil,
            isMileageCurrent: isMileageCurrent,
            mileageObservedAt: mileageObservedAt
        )
    }

    func load() async {
        // One moment for every projection on the board, so they cannot disagree with each other.
        let moment = now()
        do {
            let vehicle = try await store.currentVehicle()
            let readings = try await store.odometerReadings()
            let latest = readings.latest
            let completions = try await store.maintenanceCompletions()
            let reports = try await store.vehicleServiceReports()
            // The header and Service read mileage from one context, so they cannot disagree
            // (REQ-BOARD-026, ADR 0010).
            let context = MaintenanceContext(
                now: moment, latestReading: latest, completions: completions, reports: reports
            )
            vehicleID = vehicle.id
            photoID = vehicle.photoID
            isMileageCurrent = context.mileage == .known
            mileageObservedAt = context.observedAt
            state.car = ProvisionalCarContext(vehicle: vehicle, observedKm: context.observedKm)
            state.carBody = vehicle.body
            state.carPhoto = vehicle.photoID.flatMap { photoPreparation?.photos.files(for: $0) }
            state.mileage = CarBoardMileage(odometerKm: state.car.odometerKm)
            state.mileageRecency = context.observedAt.map {
                MileageRecency(observedAt: $0, now: moment, calendar: calendar)
            }
            state.notes = try await NotesSummary(notes: store.notes())
            state.history = try await HistoryTimeline(events: store.historyEvents(), completions: completions)
            state.service = try await MaintenanceEngine().states(
                policies: store.maintenancePolicies(),
                completions: completions,
                reports: reports,
                context: context
            ).byUrgency
            // The tile projects the same planned dates as the Road screen; insurance has no tile of its own
            // (ADR 0032).
            state.road = try await RoadProjector().project(RoadContext(
                now: moment,
                maintenanceStates: state.service,
                plannedEvents: store.plannedEvents().map(\.roadEvent),
                history: state.history,
                mileageObservations: MileageObservation.history(
                    readings: readings, completions: completions, reports: reports
                ),
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
    /// a placeholder must never be written back as a user-supplied fact (core C2). `body` is `nil`, or the
    /// body already shown, when the owner did not change it, so SUV is never written on the owner's behalf.
    /// `opening` is the car the editor opened over; without one, the car as loaded now stands in for it.
    func saveCar(
        name: String,
        odometerText: String,
        body: CarBody? = nil,
        photo: CarPhotoEdit = .unchanged,
        opening: CarEditorOpening? = nil
    ) async -> Bool {
        let kilometers = InputParsing.kilometers(from: odometerText)
        if case .invalid = kilometers {
            return fail(.invalidOdometer)
        }
        // An earlier load may have failed; without the car there is nothing to attach the edit to.
        if vehicleID == nil {
            await load()
        }
        guard vehicleID != nil else { return fail(.saveFailed) }

        // The new files are written before any command, so a photo that cannot be read or stored changes
        // nothing; they stay unreferenced until the photo command succeeds.
        let newPhotoID: CarPhotoID?
        do {
            newPhotoID = try await storeNewPhoto(photo)
        } catch {
            return fail(.saveFailed)
        }
        let replacedPhotoID = photoID
        let commands = changes(name: name, kilometers: kilometers, opening: opening ?? editorOpening)
            + profileChanges(body: body, photo: photo, newPhotoID: newPhotoID)

        var savedAnything = false
        for command in commands {
            do {
                try await store.execute(command, now: now())
            } catch {
                // The car does not point at the new files, so they go; the old photo stays as it was.
                if let newPhotoID {
                    await photoPreparation?.discard(newPhotoID)
                }
                await load()
                return fail(Self.failure(savedAnything: savedAnything, failing: command))
            }
            savedAnything = true
            // Neither the body nor the photo sends an analytics event (ADR 0040 "Privacy").
            if command.isOdometerReading {
                analytics.track(.odometerUpdated(source: .explicit, anomalyConfirmation: .noAnomaly))
            }
        }
        // Only now is the old id unreferenced: deleting earlier could leave the car pointing at nothing.
        if let replacedPhotoID, commands.contains(where: \.isCarPhoto) {
            await photoPreparation?.discard(replacedPhotoID)
        }
        await load()
        // A stale failure from an earlier attempt must not outlive a successful save.
        state.failure = nil
        return true
    }

    /// The name and mileage commands, which a save runs first, as before the car had a profile. Each is written
    /// only when the owner changed it from what the editor opened over: Pit may have recorded a newer one
    /// meanwhile, and an untouched field must not put the old value back (REQ-PIT-026).
    private func changes(name: String, kilometers: WholeNumberInput, opening: CarEditorOpening) -> [DomainCommand] {
        guard let vehicleID else { return [] }
        var commands: [DomainCommand] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty, trimmedName != opening.car.name, trimmedName != state.car.name {
            let fact = VehicleFact(field: .name, value: trimmedName)
            commands.append(.recordVehicleFact(.init(vehicleID: vehicleID, fact: fact)))
        }
        if case let .value(value) = kilometers, recordsReading(value, opening: opening) {
            let reading = OdometerReading(vehicleID: vehicleID, value: Double(value), recordedAt: now())
            commands.append(.recordOdometerReading(.init(reading: reading)))
        }
        return commands
    }

    /// The body, then the photo last, so the old photo's files go only once nothing can fail.
    private func profileChanges(body: CarBody?, photo: CarPhotoEdit, newPhotoID: CarPhotoID?) -> [DomainCommand] {
        guard let vehicleID else { return [] }
        var commands: [DomainCommand] = []
        if let body, body != state.carBody {
            commands.append(.setCarBody(.init(vehicleID: vehicleID, body: body)))
        }
        switch photo {
        case .unchanged:
            break
        case .replace:
            commands.append(.setCarPhoto(.init(vehicleID: vehicleID, photoID: newPhotoID)))
        case .remove where photoID != nil:
            commands.append(.setCarPhoto(.init(vehicleID: vehicleID, photoID: nil)))
        case .remove:
            break
        }
        return commands
    }

    /// Whether the editor's mileage is recorded. An edited number is, unless it is already the current mileage. The
    /// number the editor opened with is recorded again only over a stale mileage, since it tells the engine where
    /// the car is today (REQ-BOARD-026), and only while that mileage is still the newest: once anything newer was
    /// recorded, the untouched number would move the mileage backwards.
    private func recordsReading(_ value: Int, opening: CarEditorOpening) -> Bool {
        guard value == opening.car.odometerKm else {
            return value != state.car.odometerKm || !isMileageCurrent
        }
        let nothingNewer = mileageObservedAt == opening.mileageObservedAt && state.car.odometerKm == value
        return !opening.isMileageCurrent && nothingNewer
    }

    /// The picked photo's new id once its files are stored, or `nil` when the photo does not change.
    private func storeNewPhoto(_ photo: CarPhotoEdit) async throws(CarPhotoStoreError) -> CarPhotoID? {
        guard case let .replace(data) = photo else { return nil }
        // Without the App Group container there is nowhere to keep the files.
        guard let photoPreparation else { throw .writeFailed }
        return try await photoPreparation.store(picked: data)
    }

    /// A failed command's message names what was already saved, so it never claims that nothing changed.
    private static func failure(savedAnything: Bool, failing command: DomainCommand) -> CarBoardFailure {
        guard savedAnything else { return .saveFailed }
        // Only the name runs before the mileage.
        return command.isOdometerReading ? .mileageNotSaved : .profileNotSaved
    }

    func dismissFailure() {
        state.failure = nil
    }

    private func fail(_ failure: CarBoardFailure) -> Bool {
        state.failure = failure
        return false
    }
}

private extension DomainCommand {
    var isOdometerReading: Bool {
        if case .recordOdometerReading = self {
            true
        } else {
            false
        }
    }

    var isCarPhoto: Bool {
        if case .setCarPhoto = self {
            true
        } else {
            false
        }
    }
}
