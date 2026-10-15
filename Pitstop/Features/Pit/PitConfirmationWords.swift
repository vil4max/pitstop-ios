import SwiftUI

extension ValidatedContent {
    /// What confirming does to a maintenance cycle, said before the owner confirms: a completion
    /// resets its cycle, a dashboard reading never does (core C5, ADR 0035).
    var cycleNote: LocalizedStringKey? {
        switch self {
        case .maintenanceCompletion: "pit.confirm.resetsCycle"
        case .vehicleServiceReport: "pit.confirm.reportNoReset"
        case .note, .odometerReading, .vehicleFact, .maintenancePolicy, .vehicleEvent, .expense: nil
        }
    }
}

/// What Pit's capture sheet says about a proposal, a question and a destination.
extension PitCaptureView {
    func facts(_ content: ValidatedContent) -> [Text] {
        switch content {
        case let .maintenanceCompletion(_, date, kilometers):
            [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
                + (kilometers.map { [Text("pit.confirm.atMileage \($0)")] } ?? [])
        case let .odometerReading(_, date):
            [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
        case let .vehicleEvent(kind, date, kilometers, amount):
            eventFacts(kind: kind, date: date, kilometers: kilometers, amount: amount)
        case let .expense(kind, date, kilometers, amount):
            eventFacts(kind: kind, date: date, kilometers: kilometers, amount: amount)
        case let .maintenancePolicy(_, distance, months):
            (distance.map { [Text("pit.confirm.everyKm \($0)")] } ?? [])
                + (months.map { [Text("pit.confirm.everyMonths \($0)")] } ?? [])
        case let .vehicleServiceReport(_, date, kilometers, distance, unit, days):
            // The reading exactly as it will be stored, in the unit the car showed (ADR 0035).
            VehicleServiceReport.carSaysTexts(distance: distance, unit: unit, days: days)
                .map { Text("pit.confirm.carSays \($0)") }
                + [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
                + (kilometers.map { [Text("pit.confirm.atMileage \($0)")] } ?? [])
        case .note, .vehicleFact:
            []
        }
    }

    func eventFacts(kind: HistoryEventKind, date: Date, kilometers: Int?, amount: Decimal?) -> [Text] {
        var facts = [Text(kind.title), Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
        if let kilometers {
            facts.append(Text("pit.confirm.atMileage \(kilometers)"))
        }
        if let amount {
            facts.append(Text("pit.confirm.amount \(FeatureFormat.amount(amount))"))
        }
        return facts
    }

    func destinationName(_ destination: PitDestination) -> LocalizedStringKey {
        switch destination {
        case .notes: "pit.saved.to.notes"
        case .history: "pit.saved.to.history"
        case .service: "pit.saved.to.service"
        case .carBoard: "pit.saved.to.car"
        }
    }

    func summary(_ content: ValidatedContent) -> Text {
        switch content {
        case let .maintenanceCompletion(operation, _, _): Text("pit.confirm.completion \(operation.titleText)")
        case let .odometerReading(kilometers, _): Text("pit.confirm.reading \(Int(kilometers.rounded()))")
        case .vehicleEvent, .expense: Text("pit.confirm.event")
        case let .vehicleFact(fact): Text("pit.confirm.fact \(fact.field.title) \(fact.value)")
        case let .maintenancePolicy(operation, _, _): Text("pit.confirm.policy \(operation.titleText)")
        case let .vehicleServiceReport(operation, _, _, _, _, _):
            Text("pit.confirm.vehicleReport \(operation.titleText)")
        case .note: Text("pit.confirm.note")
        }
    }

    func conflictText(_ conflict: ProposalConflict) -> Text {
        switch conflict {
        case let .odometerBelowLatest(latest): Text("pit.confirm.conflict.mileage \(Int(latest.rounded()))")
        case let .replacesVehicleFact(_, existing): Text("pit.confirm.conflict.fact \(existing)")
        }
    }

    func question(_ field: ProposalField, kind: ProposalKind) -> LocalizedStringKey {
        switch field {
        case .odometerKm: "pit.clarify.odometerKm"
        // The car's reading names no work done; asking "what was done?" would suggest it does.
        case .operationID where kind == .vehicleServiceReport: "pit.clarify.operationID.report"
        case .operationID: "pit.clarify.operationID"
        case .vehicleFact: "pit.clarify.vehicleFact"
        case .policyInterval: "pit.clarify.policyInterval"
        case .eventKind: "pit.clarify.eventKind"
        case .amount: "pit.clarify.amount"
        case .remainingValue: "pit.clarify.remainingValue"
        }
    }

    func link(for destination: PitDestination) -> LocalizedStringKey? {
        switch destination {
        case .notes: "pit.saved.openNotes"
        case .history: "pit.saved.openHistory"
        case .service: "pit.saved.openService"
        case .carBoard: nil
        }
    }
}

private extension VehicleFactField {
    var title: Text {
        switch self {
        case .name: Text("carEditor.name.section")
        case .make: Text("pit.fact.make")
        case .model: Text("pit.fact.model")
        case .year: Text("pit.fact.year")
        case .vin: Text(verbatim: "VIN")
        }
    }
}
