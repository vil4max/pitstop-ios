import Foundation
@testable import Pitstop
import Testing

typealias CaptureFixtures = DomainFixtures.Capture

let captureTestNow = DomainFixtures.Odometers.baseDate.addingTimeInterval(3600)

func captureContext(
    latestOdometerKm: Double? = nil,
    vehicle: Vehicle = DomainFixtures.Vehicles.standard
) -> ProposalValidationContext {
    ProposalValidationContext(vehicle: vehicle, latestOdometerKm: latestOdometerKm, now: captureTestNow)
}

func captureInput(
    _ text: String,
    source: CaptureSource = .pitText,
    feature: VisibleFeature? = nil,
    vehicleID: VehicleID = DomainFixtures.Vehicles.defaultID
) -> CaptureInput {
    CaptureInput(
        payload: .text(text),
        source: source,
        capturedAt: DomainFixtures.Odometers.baseDate,
        selectedVehicleID: vehicleID,
        visibleFeature: feature
    )
}

func validated(
    _ proposal: MemoryProposal,
    input: CaptureInput,
    context: ProposalValidationContext = captureContext()
) throws -> ValidatedProposal {
    guard case let .valid(result) = ProposalValidator().validate(proposal, input: input, context: context) else {
        throw CaptureExpectationError.notValid
    }
    return result
}

enum CaptureExpectationError: Error {
    case notValid
}

extension HistoryEvent {
    func dated(_ date: Date) -> HistoryEvent {
        HistoryEvent(
            id: id,
            vehicleID: vehicleID,
            kind: kind,
            date: date,
            odometerKm: odometerKm,
            amount: amount,
            note: note
        )
    }
}
