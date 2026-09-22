import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1

// Notes, History events and planned dates: the app's own records. They stay out of the widget
// extension, which maps only what the next-service widget reads (RecordMapping.swift, ADR 0036).

extension Schema1.NoteRecord {
    convenience init(_ note: Note) {
        self.init(
            id: note.id,
            vehicleID: note.vehicleID?.rawValue,
            rawText: note.rawText,
            createdAt: note.createdAt,
            status: note.status.rawValue,
            contexts: note.canonicalContexts.map(\.rawValue).sorted()
        )
    }

    var domain: Note {
        Note(
            id: id,
            vehicleID: vehicleID.map(VehicleID.init(rawValue:)),
            rawText: rawText,
            createdAt: createdAt,
            // An unreadable status must not hide the note, so it falls back to visible.
            status: NoteStatus(rawValue: status) ?? .active,
            canonicalContexts: Set(contexts.compactMap(NoteContext.init(rawValue:)))
        )
    }
}

extension Schema1.HistoryEventRecord {
    convenience init(_ event: HistoryEvent) {
        self.init(
            id: event.id,
            vehicleID: event.vehicleID.rawValue,
            kind: event.kind.rawValue,
            date: event.date,
            odometerKm: event.odometerKm,
            amount: event.amount,
            note: event.note
        )
    }

    var domain: HistoryEvent {
        HistoryEvent(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            kind: HistoryEventKind(rawValue: kind) ?? .other,
            date: date,
            odometerKm: odometerKm,
            amount: amount,
            note: note
        )
    }
}

extension PitstopSchemaV3.PlannedVehicleEventRecord {
    static let insuranceExpiryKind = "insuranceExpiry"
    private static let otherKind = "other"

    convenience init(_ event: PlannedDatedEvent) {
        self.init(
            id: event.id,
            vehicleID: event.vehicleID.rawValue,
            kind: event.isInsuranceExpiry ? Self.insuranceExpiryKind : Self.otherKind,
            label: event.label,
            date: event.date,
            createdAt: event.createdAt
        )
    }

    var domain: PlannedDatedEvent {
        PlannedDatedEvent(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            // A kind this version cannot read stays visible and deletable as the owner's own date rather
            // than disappearing, and it never blocks a new insurance expiry.
            kind: kind == Self.insuranceExpiryKind ? .insuranceExpiry : .other(label: label),
            date: date,
            createdAt: createdAt
        )
    }

    func update(from event: PlannedDatedEvent) {
        kind = event.isInsuranceExpiry ? Self.insuranceExpiryKind : Self.otherKind
        label = event.label
        date = event.date
    }
}

extension Schema1.HistoryEventRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV1.HistoryEventRecord> {
        #Predicate { $0.id == id }
    }
}

extension PitstopSchemaV3.PlannedVehicleEventRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV3.PlannedVehicleEventRecord> {
        #Predicate { $0.id == id }
    }
}
