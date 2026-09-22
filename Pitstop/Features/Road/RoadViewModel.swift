import Foundation
import Observation

struct RoadViewState: Equatable {
    var projection: RoadProjection?
    /// Stored planned dates, so a planned milestone on the list can be edited or deleted.
    var plannedEvents: [PlannedDatedEvent] = []
    var isLoadFailed = false
    /// Shown inside the open editor, next to the input that failed.
    var failure: RoadFailure?
    /// Shown on the list: delete happens with no sheet open.
    var listFailure: RoadFailure?
    /// Deleting waits for a confirmation that names the date (core P1, ADR 0032).
    var deleteCandidate: PlannedDatedEvent?

    func plannedEvent(id: UUID) -> PlannedDatedEvent? {
        plannedEvents.first { $0.id == id }
    }
}

enum RoadFailure: Equatable {
    case notSaved
    case dateOutOfRange
    case labelTooLong
    case insuranceAlreadyPlanned
}

/// What the planned date editor collects. The label belongs to `other` only.
struct PlannedEventDraft: Equatable {
    enum Kind: Hashable, CaseIterable {
        case insuranceExpiry
        case other
    }

    var kind: Kind
    var date: Date
    var label = ""
}

@MainActor
@Observable
final class RoadViewModel {
    private(set) var state = RoadViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date
    private let calendar: Calendar

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
            let moment = now()
            let planned = try await store.plannedEvents()
            state.projection = try await Self.projection(
                from: store, planned: planned, now: moment, calendar: calendar
            )
            state.plannedEvents = planned
            state.isLoadFailed = false
        } catch {
            state.isLoadFailed = true
        }
    }

    /// Road owns no data: it is recomputed from the same facts Service and History read, plus the
    /// owner's planned dates.
    static func projection(
        from store: any CarMemoryStore,
        planned: [PlannedDatedEvent],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws(CarMemoryStoreError) -> RoadProjection {
        let completions = try await store.maintenanceCompletions()
        let readings = try await store.odometerReadings()
        let context = MaintenanceContext(
            now: now,
            latestReading: readings.latest,
            completions: completions
        )
        let states = try await MaintenanceEngine().states(
            policies: store.maintenancePolicies(),
            completions: completions,
            context: context
        )
        let history = try await HistoryTimeline(events: store.historyEvents(), completions: completions)
        return RoadProjector().project(RoadContext(
            now: now,
            maintenanceStates: states,
            plannedEvents: planned.map(\.roadEvent),
            history: history,
            mileageObservations: MileageObservation.history(readings: readings, completions: completions),
            calendar: calendar
        ))
    }

    // MARK: - Planned dates

    /// Insurance first while the car has none on Road: it is the one kind this entry exists for.
    func newDraft() -> PlannedEventDraft {
        PlannedEventDraft(kind: canChooseInsurance(editing: nil) ? .insuranceExpiry : .other, date: today)
    }

    func draft(for event: PlannedDatedEvent) -> PlannedEventDraft {
        PlannedEventDraft(
            kind: event.isInsuranceExpiry ? .insuranceExpiry : .other,
            date: event.date,
            label: event.label ?? ""
        )
    }

    /// One insurance expiry per car on Road; the one being edited may keep its kind (ADR 0032).
    func canChooseInsurance(editing existing: PlannedDatedEvent?) -> Bool {
        let moment = now()
        return !state.plannedEvents.contains {
            $0.isInsuranceExpiry && $0.id != existing?.id && $0.isOnRoad(now: moment)
        }
    }

    /// From today, or from the stored date when correcting one that has just passed, up to the limit.
    func dateRange(editing existing: PlannedDatedEvent?) -> ClosedRange<Date> {
        let moment = now()
        let lower = min(existing?.date ?? today, today)
        let upper = calendar.startOfDay(for: PlannedEventLimits.latestDate(now: moment))
        return lower ... max(lower, upper)
    }

    /// The owner enters the date directly, so it is already confirmed; the command still checks its
    /// invariants. Returns `true` only after persistence.
    func save(_ draft: PlannedEventDraft, replacing existing: PlannedDatedEvent? = nil) async -> Bool {
        let moment = now()
        // A date-only plan: the day it falls on, in the owner's calendar, not the time it was typed.
        let date = calendar.startOfDay(for: draft.date)
        guard PlannedEventLimits.isPlausibleDate(date, now: moment) else { return fail(.dateOutOfRange) }
        let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline).joined(separator: " ")
        guard PlannedEventLimits.isLabelWithinLimit(label) else { return fail(.labelTooLong) }
        let kind: PlannedDatedEvent.Kind = switch draft.kind {
        case .insuranceExpiry: .insuranceExpiry
        case .other: .other(label: label.isEmpty ? nil : label)
        }
        do {
            let vehicleID = try await store.currentVehicle().id
            let event = PlannedDatedEvent(
                id: existing?.id ?? UUID(),
                vehicleID: vehicleID,
                kind: kind,
                date: date,
                createdAt: existing?.createdAt ?? moment
            )
            let command: DomainCommand = existing == nil
                ? .addPlannedEvent(AddPlannedEventCommand(event: event))
                : .updatePlannedEvent(UpdatePlannedEventCommand(event: event))
            try await store.execute(command, now: moment)
        } catch .insuranceExpiryAlreadyPlanned {
            return fail(.insuranceAlreadyPlanned)
        } catch .invalidCommand(.plannedDateOutOfRange) {
            return fail(.dateOutOfRange)
        } catch .invalidCommand(.plannedLabelTooLong) {
            return fail(.labelTooLong)
        } catch {
            return fail(.notSaved)
        }
        await load()
        state.failure = nil
        return true
    }

    func requestDelete(_ event: PlannedDatedEvent) {
        state.deleteCandidate = event
    }

    func cancelDelete() {
        state.deleteCandidate = nil
    }

    /// The dialog's destructive action. It takes the event the dialog presented, because dismissing the
    /// dialog can clear the pending request before this task runs (the ADR 0031 pattern).
    func confirmDelete(_ event: PlannedDatedEvent) async -> Bool {
        state.deleteCandidate = nil
        do {
            try await store.execute(.removePlannedEvent(RemovePlannedEventCommand(eventID: event.id)), now: now())
        } catch {
            state.listFailure = .notSaved
            return false
        }
        await load()
        state.listFailure = nil
        return true
    }

    func dismissFailure() {
        state.failure = nil
        state.listFailure = nil
    }

    private var today: Date {
        calendar.startOfDay(for: now())
    }

    private func fail(_ failure: RoadFailure) -> Bool {
        state.failure = failure
        return false
    }
}
