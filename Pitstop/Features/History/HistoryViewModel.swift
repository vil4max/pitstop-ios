import Foundation
import Observation

struct HistoryViewState: Equatable {
    var timeline: HistoryTimeline = .empty
    var isLoadFailed = false
    var failure: HistoryFailure?
}

enum HistoryFailure: Equatable {
    case notSaved
    case invalidOdometer
    case invalidAmount
    case futureDate
}

/// What the event editor collects. Every field except kind and date may stay empty: unknown
/// mileage or cost is recorded as unknown, not as zero.
struct HistoryEventDraft: Equatable {
    var kind: HistoryEventKind = .service
    var date: Date
    var odometerText = ""
    var amountText = ""
    var note = ""
}

@MainActor
@Observable
final class HistoryViewModel {
    private(set) var state = HistoryViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date

    init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    func load() async {
        do {
            state.timeline = try await HistoryTimeline(
                events: store.historyEvents(),
                completions: store.maintenanceCompletions()
            )
            state.isLoadFailed = false
        } catch {
            state.isLoadFailed = true
        }
    }

    func newDraft() -> HistoryEventDraft {
        HistoryEventDraft(date: now())
    }

    func draft(for event: HistoryEvent) -> HistoryEventDraft {
        HistoryEventDraft(
            kind: event.kind,
            date: event.date,
            odometerText: event.odometerKm.map(String.init) ?? "",
            amountText: event.amount.map { "\($0)" } ?? "",
            note: event.note ?? ""
        )
    }

    /// The user enters the event directly, so it is already user-confirmed; the command still
    /// checks its own invariants. Returns `true` only after persistence.
    func save(_ draft: HistoryEventDraft, replacing existing: HistoryEvent? = nil) async -> Bool {
        let odometer = InputParsing.kilometers(from: draft.odometerText)
        if case .invalid = odometer {
            return fail(.invalidOdometer)
        }
        let amountInput = InputParsing.amount(from: draft.amountText)
        if case .invalid = amountInput {
            return fail(.invalidAmount)
        }
        guard DomainCommandLimits.isNotFuture(draft.date, now: now()) else { return fail(.futureDate) }

        do {
            let vehicleID = try await store.currentVehicle().id
            var odometerKm: Int?
            if case let .value(kilometers) = odometer {
                odometerKm = kilometers
            }
            var amount: Decimal?
            if case let .value(decimal) = amountInput {
                amount = decimal
            }
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let event = HistoryEvent(
                id: existing?.id ?? UUID(),
                vehicleID: vehicleID,
                kind: draft.kind,
                date: draft.date,
                odometerKm: odometerKm,
                amount: amount,
                note: note.isEmpty ? nil : note
            )
            let command: DomainCommand = existing == nil
                ? .recordVehicleEvent(RecordVehicleEventCommand(event: event))
                : .correctVehicleEvent(CorrectVehicleEventCommand(event: event))
            try await store.execute(command, now: now())
        } catch {
            return fail(.notSaved)
        }
        await load()
        state.failure = nil
        return true
    }

    func dismissFailure() {
        state.failure = nil
    }

    private func fail(_ failure: HistoryFailure) -> Bool {
        state.failure = failure
        return false
    }
}
