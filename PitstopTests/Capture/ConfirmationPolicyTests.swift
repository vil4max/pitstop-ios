import Foundation
@testable import Pitstop
import Testing

@Suite("Confirmation policy")
struct ConfirmationPolicyTests {
    private let policy = ConfirmationPolicy()

    @Test(
        "REQ-CAPTURE-015: every kind yields one of the five outcomes, stable across evaluations",
        arguments: ProposalKind.allCases
    )
    func policyIsDeterministic(kind: ProposalKind) throws {
        let capture = captureInput("масло 85000")
        let proposal = try MemoryProposal(
            id: #require(UUID(uuidString: "F0000000-0000-0000-0000-0000000000AA")),
            sourceInputID: capture.id,
            kind: kind,
            rawText: capture.payload.rawContent,
            extractedOdometerKm: 85000,
            extractedOperationID: .engineOilService,
            extractedVehicleFact: VehicleFact(field: .make, value: "Example Motors"),
            extractedDistanceIntervalKm: 7500,
            extractedEventKind: .service,
            extractedAmount: 100
        )
        let first = policy.outcome(for: ProposalValidator().validate(
            proposal,
            input: capture,
            context: captureContext()
        ))
        let second = policy.outcome(for: ProposalValidator().validate(
            proposal,
            input: capture,
            context: captureContext()
        ))
        #expect(first == second)
        // No kind built from extracted structure may skip confirmation except notes and readings.
        let mayAutoAccept: Set<ProposalKind> = [.rawNote, .contextualNote, .odometerReading]
        #expect(first != .autoAcceptSafe || mayAutoAccept.contains(kind))
    }

    @Test("REQ-CAPTURE-016: a maintenance completion gets no permit before the user confirms")
    func completionNeedsConfirmation() throws {
        let result = try validated(CaptureFixtures.oilCompletionProposal, input: CaptureFixtures.rawVoiceInput)

        #expect(policy.outcome(for: result) == .confirmCompact)
        #expect(policy.permit(for: result, userConfirmed: false) == nil)

        let permit = try #require(policy.permit(for: result, userConfirmed: true))
        #expect(permit.basis == .userConfirmed)
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)
        guard case let .confirmMaintenanceCompletion(confirm) = command else {
            Issue.record("expected a completion command, got \(command)")
            return
        }
        #expect(confirm.completion.operationID == .engineOilService)
        #expect(confirm.completion.odometerKm == 85000)
        #expect(confirm.completion.vehicleID == DomainFixtures.Vehicles.defaultID)
    }

    @Test("REQ-CAPTURE-016: a permit maps only the content it was issued for, even when IDs are reused")
    func permitCarriesItsOwnContent() throws {
        let capture = CaptureFixtures.rawVoiceInput
        let sharedID = UUID()
        let note = RawProposalFactory().proposal(for: capture, id: sharedID)
        let completion = MemoryProposal(
            id: sharedID,
            sourceInputID: capture.id,
            kind: .maintenanceCompletion,
            rawText: capture.payload.rawContent,
            extractedOperationID: .engineOilService
        )
        let notePermit = try #require(policy.permit(for: validated(note, input: capture), userConfirmed: false))
        #expect(try policy.permit(for: validated(completion, input: capture), userConfirmed: false) == nil)

        let command = try DomainCommandMapper().command(for: notePermit, now: captureTestNow)

        guard case .createNote = command else {
            Issue.record("an auto-accepted note permit produced \(command)")
            return
        }
    }

    @Test(
        "REQ-CAPTURE-017: exact applicability facts are never auto-accepted",
        arguments: [VehicleFactField.make, .model, .year, .vin]
    )
    func applicabilityFactNeedsConfirmation(field: VehicleFactField) throws {
        let capture = captureInput("у меня кестрел 2019", vehicleID: DomainFixtures.Vehicles.secondaryID)
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .vehicleFact,
            rawText: capture.payload.rawContent,
            confidence: 0.99,
            extractedVehicleFact: VehicleFact(field: field, value: "2019")
        )
        let result = try validated(
            proposal,
            input: capture,
            context: captureContext(vehicle: DomainFixtures.Vehicles.unconfigured)
        )
        #expect(policy.outcome(for: result) == .confirmCompact)
    }

    @Test("REQ-CAPTURE-017: replacing a known fact is a conflict that needs confirmation")
    func conflictingFactNeedsConfirmation() throws {
        let capture = captureInput("назови машину Ласточка")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .vehicleFact,
            rawText: capture.payload.rawContent,
            extractedVehicleFact: VehicleFact(field: .name, value: "Ласточка")
        )

        let result = try validated(proposal, input: capture)

        #expect(result.conflicts == [.replacesVehicleFact(field: .name, existing: "Kestrel")])
        #expect(policy.outcome(for: result) == .confirmCompact)
    }

    @Test("REQ-CAPTURE-019: naming the provisional car replaces a placeholder, not a fact")
    func namingProvisionalCarIsLowRisk() throws {
        let provisional = Vehicle(id: DomainFixtures.Vehicles.secondaryID, name: ProvisionalCarContext.defaultName)
        let capture = captureInput("назови машину Ласточка", vehicleID: provisional.id)
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .vehicleFact,
            rawText: capture.payload.rawContent,
            extractedVehicleFact: VehicleFact(field: .name, value: "Ласточка")
        )

        let result = try validated(proposal, input: capture, context: captureContext(vehicle: provisional))

        #expect(result.conflicts.isEmpty)
        #expect(policy.outcome(for: result) == .autoAcceptSafe)
    }

    @Test("REQ-CAPTURE-018: a custom interval change needs confirmation")
    func policyDraftNeedsConfirmation() throws {
        let capture = captureInput("масло меняю каждые 7500")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .maintenancePolicyDraft,
            rawText: capture.payload.rawContent,
            extractedOperationID: .engineOilService,
            extractedDistanceIntervalKm: 7500
        )

        let result = try validated(proposal, input: capture)

        #expect(policy.outcome(for: result) == .confirmCompact)
        let permit = try #require(policy.permit(for: result, userConfirmed: true))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)
        #expect(command == .setMaintenancePolicy(SetMaintenancePolicyCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            policy: MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 7500, source: .userCustom)
        )))
    }

    @Test("REQ-CAPTURE-019: a valid low-risk reading maps to a command without confirmation")
    func lowRiskReadingIsAutoAccepted() throws {
        let result = try validated(
            CaptureFixtures.validOdometerProposal,
            input: CaptureFixtures.widgetOdometerInput,
            context: captureContext(latestOdometerKm: 84200)
        )

        #expect(policy.outcome(for: result) == .autoAcceptSafe)
        let permit = try #require(policy.permit(for: result, userConfirmed: false))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)
        guard case let .recordOdometerReading(record) = command else {
            Issue.record("expected an odometer command, got \(command)")
            return
        }
        #expect(record.reading.value == 85500)
        #expect(record.reading.source == .pitCapture)
        #expect(record.reading.recordedAt == CaptureFixtures.widgetOdometerInput.capturedAt)
    }

    @Test(
        "ADR-0006: a reading below the latest known one is confirmed, equal or above is not",
        arguments: [(84199.0, ConfirmationOutcome.confirmCompact), (84200, .autoAcceptSafe), (84201, .autoAcceptSafe)]
    )
    func readingBelowLatestNeedsConfirmation(kilometers: Double, expected: ConfirmationOutcome) throws {
        let capture = captureInput("пробег")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "пробег",
            extractedOdometerKm: kilometers
        )
        let result = try validated(proposal, input: capture, context: captureContext(latestOdometerKm: 84200))
        #expect(policy.outcome(for: result) == expected)
    }

    @Test(
        "REQ-DOMAIN-018: model confidence can demand confirmation but never grants validity",
        arguments: [(0.79, ConfirmationOutcome.confirmCompact), (0.8, .autoAcceptSafe), (0.81, .autoAcceptSafe)]
    )
    func confidenceOnlyRaisesConfirmation(confidence: Double, expected: ConfirmationOutcome) throws {
        let capture = captureInput("пробег")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "пробег",
            confidence: confidence,
            extractedOdometerKm: 90000
        )
        #expect(try policy.outcome(for: validated(proposal, input: capture)) == expected)

        let invalid = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: "пробег",
            confidence: 1,
            extractedOdometerKm: -5
        )
        let validation = ProposalValidator().validate(invalid, input: capture, context: captureContext())
        #expect(policy.outcome(for: validation) == .preserveRaw)
    }

    @Test(
        "REQ-DOMAIN-015: events and expenses enter History only after confirmation",
        arguments: [ProposalKind.vehicleEvent, .expense]
    )
    func historyKindsNeedConfirmation(kind: ProposalKind) throws {
        let capture = captureInput("помыл машину за 1200")
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: kind,
            rawText: capture.payload.rawContent,
            extractedEventKind: .carWash,
            extractedAmount: 1200
        )
        let result = try validated(proposal, input: capture)
        #expect(policy.outcome(for: result) == .confirmCompact)
        #expect(policy.permit(for: result, userConfirmed: false) == nil)
    }

    @Test("REQ-CAPTURE-014: an intention read as a reminder is saved as a note, never as work or a reminder")
    func intentionRemainsANote() throws {
        let capture = captureInput("заменить дворники")
        let interpreted = MemoryProposal(
            sourceInputID: capture.id,
            kind: .reminderCandidate,
            rawText: capture.payload.rawContent,
            confidence: 0.9,
            extractedOperationID: "wiperBlades"
        )
        let validation = ProposalValidator().validate(interpreted, input: capture, context: captureContext())
        #expect(policy.outcome(for: validation) == .preserveRaw)

        let fallback = try validated(RawProposalFactory().proposal(for: capture), input: capture)
        let permit = try #require(policy.permit(for: fallback, userConfirmed: false))
        let command = try DomainCommandMapper().command(for: permit, now: captureTestNow)

        #expect(command == .createNote(CreateNoteCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            rawText: "заменить дворники"
        )))
    }

    @Test("ADR-0006: a low-confidence name is confirmed even though naming is low risk")
    func lowConfidenceNameNeedsConfirmation() throws {
        let provisional = Vehicle(id: DomainFixtures.Vehicles.secondaryID, name: ProvisionalCarContext.defaultName)
        let capture = CaptureInput(
            payload: .text("ласточка"),
            source: .pitText,
            capturedAt: DomainFixtures.Odometers.baseDate
        )
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .vehicleFact,
            rawText: "ласточка",
            confidence: 0.4,
            extractedVehicleFact: VehicleFact(field: .name, value: "Ласточка")
        )
        let result = try validated(proposal, input: capture, context: captureContext(vehicle: provisional))
        #expect(policy.outcome(for: result) == .confirmCompact)
    }
}
