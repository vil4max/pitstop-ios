import Foundation
@testable import Pitstop
import Testing

@Suite("Proposal validation")
struct ProposalValidatorTests {
    @Test(
        "REQ-CAPTURE-006: unsupported meaning degrades to raw preservation",
        arguments: [ProposalKind.reminderCandidate, .unknown]
    )
    func unsupportedKindPreservesRaw(kind: ProposalKind) {
        let capture = captureInput("Напомни про страховку в марте")
        let proposal = MemoryProposal(sourceInputID: capture.id, kind: kind, rawText: capture.payload.rawContent)

        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())

        #expect(validation == .preserveRaw(proposal, reason: .unsupportedKind))
        #expect(ConfirmationPolicy().outcome(for: validation) == .preserveRaw)
    }

    @Test("REQ-CAPTURE-006: after degradation the same input is saved as a raw note through the shared path")
    func degradedProposalIsSavedRaw() throws {
        let capture = captureInput("Напомни про страховку в марте")
        let unsupported = MemoryProposal(sourceInputID: capture.id, kind: .unknown, rawText: capture.payload.rawContent)
        let degraded = ProposalValidator().validate(unsupported, input: capture, context: captureContext())
        guard case .preserveRaw = degraded else {
            Issue.record("expected degradation, got \(degraded)")
            return
        }

        let result = try validated(RawProposalFactory().proposal(for: capture), input: capture)
        let permit = try #require(ConfirmationPolicy().permit(for: result, userConfirmed: false))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)

        #expect(command == .createNote(CreateNoteCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            rawText: "Напомни про страховку в марте"
        )))
    }

    @Test("ADR-0006: a capture made for another vehicle writes no structured fact to the current one")
    func vehicleMismatchPreservesRaw() {
        let capture = CaptureInput(
            payload: .text("85500"),
            source: .widget,
            capturedAt: DomainFixtures.Odometers.baseDate,
            selectedVehicleID: DomainFixtures.Vehicles.secondaryID
        )
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "85500",
            extractedOdometerKm: 85500
        )
        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())
        #expect(validation == .preserveRaw(proposal, reason: .vehicleMismatch))
    }

    @Test("REQ-CAPTURE-006: the raw fallback still saves when the vehicle or the clock disagrees")
    func rawFallbackSurvivesGuards() throws {
        let capture = CaptureInput(
            payload: .text("85500"),
            source: .widget,
            capturedAt: captureTestNow.addingTimeInterval(3600),
            selectedVehicleID: DomainFixtures.Vehicles.secondaryID
        )

        let result = try validated(RawProposalFactory().proposal(for: capture), input: capture)
        let permit = try #require(ConfirmationPolicy().permit(for: result, userConfirmed: false))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)

        #expect(command == .createNote(CreateNoteCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            rawText: "85500"
        )))
    }

    @Test(
        "REQ-DOMAIN-009: work dated in the future keeps its wording and yields no completion",
        arguments: [
            (DomainCommandLimits.futureTolerance, true),
            (DomainCommandLimits.futureTolerance + 1, false),
            (TimeInterval(20 * 3600), false),
        ]
    )
    func futureDatedWorkIsNotValid(offset: TimeInterval, isValid: Bool) {
        let capture = CaptureInput(payload: .text("масло поменяю завтра"), source: .pitText, capturedAt: captureTestNow)
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .maintenanceCompletion,
            rawText: capture.payload.rawContent,
            extractedOperationID: .engineOilService,
            extractedDate: captureTestNow.addingTimeInterval(offset)
        )
        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())
        if isValid {
            guard case .valid = validation else {
                Issue.record("expected valid, got \(validation)")
                return
            }
        } else {
            #expect(validation == .preserveRaw(proposal, reason: .invalidExtractedValue))
        }
    }

    @Test("REQ-CAPTURE-006: an unreadable model year keeps the wording", arguments: ["двадцатый", "1885", "3000"])
    func invalidYearPreservesRaw(year: String) {
        let capture = captureInput("машина \(year) года")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .vehicleFact,
            rawText: capture.payload.rawContent,
            extractedVehicleFact: VehicleFact(field: .year, value: year)
        )
        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())
        #expect(validation == .preserveRaw(proposal, reason: .invalidExtractedValue))
    }

    @Test("REQ-DOMAIN-011: a proposal that rewrites the user's wording is not trusted")
    func alteredWordingIsRejected() {
        let capture = captureInput("поменял масло вроде")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .maintenanceCompletion,
            rawText: "Замена моторного масла выполнена",
            extractedOperationID: .engineOilService
        )

        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())

        #expect(validation == .preserveRaw(proposal, reason: .sourceMismatch))
    }

    @Test("REQ-DOMAIN-018: a proposal for another input is not trusted")
    func foreignInputIsRejected() {
        let proposal = CaptureFixtures.validOdometerProposal
        let validation = ProposalValidator().validate(proposal, input: captureInput("85500"), context: captureContext())
        #expect(validation == .preserveRaw(proposal, reason: .sourceMismatch))
    }

    @Test("ADR-0006: blank input has nothing to remember", arguments: ["", "   ", "\n\t"])
    func blankInputIsEmpty(text: String) {
        let capture = captureInput(text)
        let proposal = RawProposalFactory().proposal(for: capture)

        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())

        #expect(validation == .empty(proposal))
        #expect(ConfirmationPolicy().outcome(for: validation) == .rejectUnsupported)
    }

    @Test(
        "REQ-CAPTURE-006: implausible odometer values keep the wording and drop the structure",
        arguments: [-1, Double.nan, Double.infinity, DomainCommandLimits.maximumOdometerKm + 1]
    )
    func implausibleOdometerPreservesRaw(kilometers: Double) {
        let capture = captureInput("пробег какой-то странный")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: capture.payload.rawContent,
            extractedOdometerKm: kilometers
        )

        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())

        // NaN is not equal to itself, so the proposal cannot be compared with ==.
        guard case .preserveRaw(_, reason: .invalidExtractedValue) = validation else {
            Issue.record("expected raw preservation, got \(validation)")
            return
        }
    }

    @Test(
        "ADR-0006: odometer boundaries accept zero and the maximum",
        arguments: [0, DomainCommandLimits.maximumOdometerKm]
    )
    func odometerBoundariesAreValid(kilometers: Double) throws {
        let capture = captureInput("пробег")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "пробег",
            extractedOdometerKm: kilometers
        )
        #expect(try validated(proposal, input: capture).conflicts.isEmpty)
    }

    @Test("REQ-CAPTURE-020: clarification asks for exactly one missing field at a time")
    func clarificationIsOneQuestion() {
        let capture = captureInput("хочу менять почаще")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .maintenancePolicyDraft,
            rawText: capture.payload.rawContent
        )
        let policy = ConfirmationPolicy()

        let validation = ProposalValidator().validate(proposal, input: capture, context: captureContext())

        #expect(validation == .incomplete(proposal, missing: [.operationID, .policyInterval]))
        #expect(policy.outcome(for: validation) == .clarify)
        #expect(policy.nextClarification(for: validation) == .operationID)
    }

    @Test("REQ-DOMAIN-014: zero note contexts is valid and canonical contexts are kept")
    func contextualNoteKeepsCanonicalContexts() throws {
        let capture = captureInput("Помыть кузов перед полировкой")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .contextualNote,
            rawText: capture.payload.rawContent,
            extractedNoteContexts: [.carWash]
        )
        let result = try validated(proposal, input: capture)
        #expect(result.content == .note(text: "Помыть кузов перед полировкой", contexts: [.carWash]))
    }
}
