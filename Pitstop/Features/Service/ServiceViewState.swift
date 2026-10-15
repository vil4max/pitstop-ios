import Foundation

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
    /// Pit recorded this work within a day of the open Mark as done sheet's date, and the owner's entry differs: the
    /// sheet records nothing and asks whether to keep Pit's entry or replace it (REQ-MAINT-040).
    var markDoneConflict: MarkDoneConflict?
    /// Grows each time the sheet has to ask, so the prompt is announced to VoiceOver even when it is already shown:
    /// focus stays on the confirmation, and the prompt appears below it.
    var markDoneConflictNotices = 0

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

    /// "Track an operation" needs something left to track; unlike "Track several" it does not wait for a load.
    var canTrackOne: Bool {
        !untrackedOperations.isEmpty
    }

    /// The one "Track" toolbar menu stays available while either item is, so "Track several" waiting for the first
    /// load reads as a disabled item rather than a missing control. That is
    /// `canTrackOne` alone: "Track several" also needs something untracked, so it is never enabled without it.
    var isTrackMenuEnabled: Bool {
        canTrackOne
    }
}

/// What the confirmation must say: with another rule left, the operation stays on Service under that rule.
struct StopTrackingRequest: Equatable {
    let operation: MaintenanceOperationID
    let fallsBackToOtherPolicy: Bool
}

extension ServiceViewState {
    /// The unit of whichever is newer, the latest distance reading from the dashboard or the latest odometer
    /// reading; kilometres when neither exists.
    static func defaultReportUnit(readings: [OdometerReading], reports: [VehicleServiceReport]) -> DistanceUnit {
        let newestReport = reports.filter { $0.remainingDistance != nil }.max { $0.reportedAt < $1.reportedAt }
        if let newestReport, newestReport.reportedAt >= (readings.latest?.recordedAt ?? .distantPast) {
            return newestReport.distanceUnit
        }
        return readings.latest?.unit ?? .kilometers
    }
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
    /// A Mark as done sheet closed before it could ask about Pit's differing entry of the same work, so Pit's entry was
    /// kept and the owner's not recorded (REQ-MAINT-049). Unlike `notSaved` it invites no retry, which would record the
    /// same work twice.
    case pitAlreadyRecorded
}
