import Foundation
@testable import Pitstop
import Testing

@Suite("Capture input and raw mode")
struct CaptureInputTests {
    @Test("REQ-CAPTURE-002: every source produces the same CaptureInput contract", arguments: CaptureSource.allCases)
    func everySourceProducesCaptureInput(source: CaptureSource) throws {
        let capture = captureInput("Проверить давление в шинах", source: source)
        let proposal = RawProposalFactory().proposal(for: capture)

        let result = try validated(proposal, input: capture)

        #expect(result.source == source)
        #expect(result.content == .note(text: "Проверить давление в шинах", contexts: []))
    }

    @Test("REQ-CAPTURE-001: raw mode yields a rawNote that passes validator, policy, and mapper")
    func rawModeUsesSharedPath() throws {
        let capture = CaptureFixtures.rawTextInput
        let proposal = RawProposalFactory().proposal(for: capture)
        #expect(proposal.kind == .rawNote)
        #expect(proposal.confidence == nil)

        let result = try validated(proposal, input: capture)
        let policy = ConfirmationPolicy()
        #expect(policy.outcome(for: result) == .autoAcceptSafe)

        let permit = try #require(policy.permit(for: result, userConfirmed: false))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)
        #expect(command == .createNote(CreateNoteCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            rawText: capture.payload.rawContent
        )))
    }

    @Test(
        "REQ-CAPTURE-022: visible feature never forces the proposal kind",
        arguments: [VisibleFeature?.none] + VisibleFeature.allCases.map(Optional.some)
    )
    func screenContextIsOnlyAPrior(feature: VisibleFeature?) throws {
        let capture = captureInput("85500", feature: feature)
        let reading = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "85500",
            extractedOdometerKm: 85500
        )

        let result = try validated(reading, input: capture)

        #expect(result.content == .odometerReading(kilometers: 85500, recordedAt: capture.capturedAt))
        #expect(RawProposalFactory().proposal(for: capture).kind == .rawNote)
    }

    @Test("REQ-CAPTURE-002: recognized document text is a payload, not a separate path")
    func documentTextIsAPayload() {
        let capture = CaptureInput(payload: .recognizedDocumentText("Заказ-наряд 1042"), source: .directApp)
        #expect(capture.payload.rawContent == "Заказ-наряд 1042")
    }
}
