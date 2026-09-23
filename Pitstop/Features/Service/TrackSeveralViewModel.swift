import Foundation
import Observation

/// Optional answer about the gearbox. It only reorders the starter list and is never stored (ADR 0033).
enum GearboxAnswer: CaseIterable, Hashable {
    case notAnswered
    case dualClutch
    case otherAutomatic
    case manual
}

/// Optional answer about the drive. It only reorders the starter list and is never stored (ADR 0033).
enum DriveAnswer: CaseIterable, Hashable {
    case notAnswered
    case allWheel
    case twoWheel
}

/// Quick-entry values the owner may tap instead of typing. They are common owner choices, not a
/// recommendation for any car: none is preselected and the copy says to check the manual (core C2, ADR 0033).
enum IntervalQuickPicks {
    static let kilometers = [5000, 7500, 10000, 15000]
    static let months = [6, 12, 24]

    /// A pick is shown selected only while its field holds exactly that number, so a chip never claims a value
    /// the owner has typed away from (ADR 0033).
    static func isSelected(_ value: Int, fieldText: String) -> Bool {
        WholeNumberInput.parse(fieldText, upTo: Int.max).intValue == value
    }
}

/// The starter's order: operations the answers point to first, the catalog order otherwise, and operations
/// the answers make unlikely last. Nothing is hidden and nothing is selected by it.
enum TrackSeveralOrder {
    static func ordered(
        _ operations: [MaintenanceOperationID],
        gearbox: GearboxAnswer,
        drive: DriveAnswer
    ) -> [MaintenanceOperationID] {
        func rank(_ operation: MaintenanceOperationID) -> Int {
            switch (operation, gearbox, drive) {
            case (.dsgService, .dualClutch, _), (.awdCouplingService, _, .allWheel): 0
            case (.dsgService, .otherAutomatic, _), (.dsgService, .manual, _), (.awdCouplingService, _, .twoWheel): 2
            default: 1
            }
        }
        return operations.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }
}

enum TrackSeveralStep: Equatable {
    case choose
    case intervals
    case review
    case results

    /// The steps as the sheet's step strip names them.
    static let stripOrder: [TrackSeveralStep] = [.choose, .intervals, .review, .results]

    /// This step's position in the step strip.
    var stripIndex: Int {
        switch self {
        case .choose: 0
        case .intervals: 1
        case .review: 2
        case .results: 3
        }
    }
}

enum TrackSeveralItemResult: Equatable {
    case saved
    case failed
}

/// Typed text for one operation; both fields start blank.
struct IntervalEntry: Equatable {
    var kilometers = ""
    var months = ""
}

/// "Track several": the owner picks operations, types or taps each interval, confirms one summary, and each
/// item is saved as the owner's own policy through the existing command, one at a time (ADR 0033). Nothing
/// reaches the store before `apply()`.
@MainActor
@Observable
final class TrackSeveralViewModel {
    private(set) var step = TrackSeveralStep.choose
    var gearbox = GearboxAnswer.notAnswered
    var drive = DriveAnswer.notAnswered
    /// In the order the owner will review them, which follows the list order at the time of choosing.
    private(set) var selected: [MaintenanceOperationID] = []
    private(set) var entries: [MaintenanceOperationID: IntervalEntry] = [:]
    /// Operations whose typed interval did not pass validation on the last "Next".
    private(set) var invalid: Set<MaintenanceOperationID> = []
    /// Grows on every "Next" that fails validation, so the view scrolls and announces even when the same items
    /// fail again.
    private(set) var validationFailures = 0
    private(set) var results: [MaintenanceOperationID: TrackSeveralItemResult] = [:]
    private(set) var isSaving = false
    /// Set by the sheet's Cancel; a cancelled starter never writes, even if a save task is still queued.
    private(set) var isCancelled = false

    private let available: [MaintenanceOperationID]
    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date
    private let onSaved: @MainActor () async -> Void

    init(
        store: any CarMemoryStore,
        operations: [MaintenanceOperationID],
        now: @escaping @Sendable () -> Date = { Date() },
        onSaved: @escaping @MainActor () async -> Void = {}
    ) {
        self.store = store
        available = operations
        self.now = now
        self.onSaved = onSaved
    }

    var operations: [MaintenanceOperationID] {
        TrackSeveralOrder.ordered(available, gearbox: gearbox, drive: drive)
    }

    func isSelected(_ operation: MaintenanceOperationID) -> Bool {
        selected.contains(operation)
    }

    func toggle(_ operation: MaintenanceOperationID) {
        guard step == .choose, available.contains(operation) else { return }
        if let index = selected.firstIndex(of: operation) {
            selected.remove(at: index)
        } else {
            selected.append(operation)
        }
    }

    func entry(for operation: MaintenanceOperationID) -> IntervalEntry {
        entries[operation] ?? IntervalEntry()
    }

    func setKilometers(_ text: String, for operation: MaintenanceOperationID) {
        entries[operation, default: IntervalEntry()].kilometers = text
        invalid.remove(operation)
    }

    func setMonths(_ text: String, for operation: MaintenanceOperationID) {
        entries[operation, default: IntervalEntry()].months = text
        invalid.remove(operation)
    }

    /// A tapped quick pick fills the field exactly as typing the number would; the owner can still edit it.
    func pickKilometers(_ value: Int, for operation: MaintenanceOperationID) {
        setKilometers(String(value), for: operation)
    }

    func pickMonths(_ value: Int, for operation: MaintenanceOperationID) {
        setMonths(String(value), for: operation)
    }

    func continueToIntervals() {
        guard step == .choose, !selected.isEmpty else { return }
        // Review follows the list the owner saw, not the tap order.
        let order = operations
        selected.sort { (order.firstIndex(of: $0) ?? .max) < (order.firstIndex(of: $1) ?? .max) }
        step = .intervals
    }

    /// Every selected operation needs its own valid interval before the summary is shown.
    @discardableResult
    func continueToReview() -> Bool {
        guard step == .intervals else { return false }
        invalid = Set(selected.filter { policy(for: $0) == nil })
        guard invalid.isEmpty else {
            validationFailures += 1
            return false
        }
        step = .review
        return true
    }

    /// The failing operations in the order the owner sees them; the first is where the view scrolls.
    var invalidInListOrder: [MaintenanceOperationID] {
        selected.filter(invalid.contains)
    }

    var firstInvalid: MaintenanceOperationID? {
        invalidInListOrder.first
    }

    /// The sheet's Cancel: the starter is abandoned and nothing it holds is saved.
    func cancel() {
        guard !isSaving else { return }
        isCancelled = true
    }

    func back() {
        switch step {
        case .intervals: step = .choose
        case .review: step = .intervals
        case .choose, .results: break
        }
    }

    /// What the confirmation lists and what `apply()` saves, in the same order.
    var reviewPolicies: [MaintenancePolicy] {
        selected.compactMap(policy(for:))
    }

    var failedOperations: [MaintenanceOperationID] {
        selected.filter { results[$0] == .failed }
    }

    var savedCount: Int {
        selected.count { results[$0] == .saved }
    }

    /// The confirmation's action. Saves every item not saved yet, one command at a time, so a failure part way
    /// leaves the earlier items saved and is reported per item. Called again, it retries only the failed items.
    func apply() async {
        guard !isCancelled, step == .review || (step == .results && !failedOperations.isEmpty), !isSaving else {
            return
        }
        isSaving = true
        defer { isSaving = false }
        let pending = reviewPolicies.filter { results[$0.operationID] != .saved }
        let vehicleID: VehicleID
        do {
            vehicleID = try await store.currentVehicle().id
        } catch {
            for policy in pending {
                results[policy.operationID] = .failed
            }
            step = .results
            return
        }
        for policy in pending {
            do {
                try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now())
                results[policy.operationID] = .saved
            } catch {
                results[policy.operationID] = .failed
            }
        }
        step = .results
        if savedCount > 0 {
            await onSaved()
        }
    }

    private func policy(for operation: MaintenanceOperationID) -> MaintenancePolicy? {
        let entry = entry(for: operation)
        return OwnerInterval.policy(for: operation, kilometersText: entry.kilometers, monthsText: entry.months)
    }
}
