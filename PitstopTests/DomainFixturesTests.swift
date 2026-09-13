import Foundation
@testable import Pitstop
import Testing

@Suite("DomainFixtures & Domain Contracts")
struct DomainFixturesTests {

    // MARK: - Vehicle & Odometer Invariants (spec 02)

    @Test func vehicleConfigurationAndOdometerInvariants() {
        let vehicle = DomainFixtures.Vehicles.standard
        #expect(vehicle.id == DomainFixtures.Vehicles.defaultID)
        #expect(vehicle.name == "Golf GTI")
        #expect(vehicle.make == "Volkswagen")
        #expect(vehicle.vin == "WVWZZZAUZKP000001")

        // Odometer readings
        let kmReading = DomainFixtures.Odometers.reading84k
        #expect(kmReading.value == 84200)
        #expect(kmReading.unit == .kilometers)
        #expect(kmReading.valueInKilometers == 84200)
        #expect(kmReading.source == .manualEntry)

        let milesReading = DomainFixtures.Odometers.readingMiles
        #expect(milesReading.unit == .miles)
        #expect(milesReading.value == 50000)
        // 50,000 mi * 1.609344 = 80,467.2 km
        #expect(abs(milesReading.valueInKilometers - 80467.2) < 0.001)
    }

    // MARK: - Maintenance Invariants (spec 02)

    @Test func maintenanceOperationsAndPolicies() {
        let defaultPolicy = DomainFixtures.Maintenance.standardOilPolicy
        #expect(defaultPolicy.operationID == .engineOilService)
        #expect(defaultPolicy.distanceIntervalKm == 15000)
        #expect(defaultPolicy.timeIntervalMonths == 12)
        #expect(defaultPolicy.source == .defaultRecommendation)

        let customPolicy = DomainFixtures.Maintenance.severeOilPolicy
        #expect(customPolicy.operationID == .engineOilService)
        #expect(customPolicy.distanceIntervalKm == 7500)
        #expect(customPolicy.source == .userCustom)

        let timeOnlyPolicy = DomainFixtures.Maintenance.brakeFluidPolicy
        #expect(timeOnlyPolicy.distanceIntervalKm == nil)
        #expect(timeOnlyPolicy.timeIntervalMonths == 24)

        // Completion
        let completion = DomainFixtures.Maintenance.oilCompletionRecent
        #expect(completion.operationID == .engineOilService)
        #expect(completion.odometerKm == 84200)
    }

    // MARK: - Notes & History Invariants (spec 02)

    @Test func notesPreserveRawTextAndContexts() {
        var note = DomainFixtures.Notes.rawThought
        #expect(note.status == .active)
        #expect(note.rawText == "Кажется, левый дворник начал полосить на скорости")
        #expect(note.canonicalContexts.isEmpty)

        // Status transition to archived does not alter rawText
        note.status = .archived
        #expect(note.status == .archived)
        #expect(note.rawText == "Кажется, левый дворник начал полосить на скорости")

        let shoppingNote = DomainFixtures.Notes.archivedNote
        #expect(shoppingNote.canonicalContexts.contains(.shopping))
    }

    @Test func historyEventsContainFactualRecords() {
        let serviceEvent = DomainFixtures.History.serviceVisit
        #expect(serviceEvent.kind == .service)
        #expect(serviceEvent.odometerKm == 84200)
        #expect(serviceEvent.amount == 12500)
    }

    // MARK: - Capture Pipeline Invariants (spec 34)

    @Test func captureInputAndProposalContracts() {
        let voiceInput = DomainFixtures.Capture.rawVoiceInput
        #expect(voiceInput.source == .pitVoice)
        #expect(voiceInput.payload.rawContent == "Заменил масло и масляный фильтр на пробеге 85000")

        let proposal = DomainFixtures.Capture.oilCompletionProposal
        #expect(proposal.sourceInputID == voiceInput.id)
        #expect(proposal.kind == .maintenanceCompletion)
        #expect(proposal.extractedOdometerKm == 85000)
        #expect(proposal.extractedOperationID == .engineOilService)

        // Ambiguous proposal degrades to rawNote
        let ambiguous = DomainFixtures.Capture.ambiguousProposal
        #expect(ambiguous.kind == .rawNote)
        #expect(ambiguous.confidence == nil)
    }

    @Test func domainCommandsAreDeterministicallyFormed() {
        let noteCmd = CreateNoteCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            rawText: "Проверить давление в шинах",
            canonicalContexts: []
        )
        #expect(noteCmd.rawText == "Проверить давление в шинах")

        let odoCmd = RecordOdometerReadingCommand(reading: DomainFixtures.Odometers.reading85k)
        #expect(odoCmd.reading.value == 85500)

        let completionCmd = ConfirmMaintenanceCompletionCommand(
            completion: DomainFixtures.Maintenance.oilCompletionRecent
        )
        #expect(completionCmd.completion.operationID == .engineOilService)
    }
}
