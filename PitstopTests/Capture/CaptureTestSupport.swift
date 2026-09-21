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

extension CaptureInput {
    /// The locale of the Russian wording most fixtures use. Production sources must name their locale
    /// (ADR 0030); only tests that do not care about it build an input without one.
    static let fixtureLocaleIdentifier = "ru_RU"

    init(
        id: UUID = UUID(),
        payload: CapturePayload,
        source: CaptureSource,
        capturedAt: Date = Date(),
        selectedVehicleID: VehicleID? = nil,
        visibleFeature: VisibleFeature? = nil,
        visibleEntityID: UUID? = nil
    ) {
        self.init(
            id: id,
            payload: payload,
            source: source,
            capturedAt: capturedAt,
            localeIdentifier: Self.fixtureLocaleIdentifier,
            selectedVehicleID: selectedVehicleID,
            visibleFeature: visibleFeature,
            visibleEntityID: visibleEntityID
        )
    }
}

/// Records every input it is asked about and finds no meaning, so the wording is kept raw.
actor InputRecordingInterpreter: SemanticInterpreting {
    private(set) var inputs: [CaptureInput] = []

    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        inputs.append(input)
        return nil
    }
}
