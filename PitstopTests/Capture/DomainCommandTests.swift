import Foundation
@testable import Pitstop
import Testing

@Suite("Domain command invariants")
struct DomainCommandTests {
    private let vehicleID = DomainFixtures.Vehicles.defaultID

    @Test("REQ-CAPTURE-021: commands reject invariant violations regardless of how they were built", arguments: [
        (DomainCommand.createNote(CreateNoteCommand(rawText: "  ")), DomainCommandError.emptyNoteText),
        (.recordOdometerReading(RecordOdometerReadingCommand(reading: OdometerReading(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            value: -1,
            recordedAt: captureTestNow
        ))), .odometerOutOfRange),
        (.recordOdometerReading(RecordOdometerReadingCommand(reading: OdometerReading(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            value: 4_000_000,
            unit: .miles,
            recordedAt: captureTestNow
        ))), .odometerOutOfRange),
        (.recordVehicleFact(RecordVehicleFactCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            fact: VehicleFact(field: .vin, value: " ")
        )), .emptyVehicleFactValue),
        (.recordVehicleFact(RecordVehicleFactCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            fact: VehicleFact(field: .year, value: "1885")
        )), .invalidVehicleYear),
        (.recordVehicleFact(RecordVehicleFactCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            fact: VehicleFact(field: .year, value: "двадцатый")
        )), .invalidVehicleYear),
        (.setMaintenancePolicy(SetMaintenancePolicyCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            policy: MaintenancePolicy(operationID: .brakeFluid)
        )), .policyWithoutInterval),
        (.setMaintenancePolicy(SetMaintenancePolicyCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            policy: MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 0)
        )), .nonPositiveInterval),
        (.stopTrackingOperation(StopTrackingOperationCommand(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            operationID: MaintenanceOperationID(rawValue: " ")
        )), .emptyOperationID),
        (.recordExpense(RecordExpenseCommand(event: HistoryEvent(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            kind: .other,
            date: captureTestNow
        ))), .nonPositiveAmount),
        (.recordVehicleEvent(RecordVehicleEventCommand(event: HistoryEvent(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            kind: .carWash,
            date: captureTestNow,
            amount: 0
        ))), .nonPositiveAmount),
    ])
    func invalidCommandIsRejected(command: DomainCommand, expected: DomainCommandError) {
        #expect(throws: expected) { try command.validate(now: captureTestNow) }
    }

    @Test(
        "REQ-DOMAIN-009: work dated in the future is a plan, not a completion",
        arguments: [
            (DomainCommandLimits.futureTolerance - 1, false),
            (DomainCommandLimits.futureTolerance, false),
            (DomainCommandLimits.futureTolerance + 1, true)
        ]
    )
    func futureCompletionIsRejected(offset: TimeInterval, shouldThrow: Bool) {
        let command = DomainCommand.confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand(
            completion: MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: .engineOilService,
                performedAt: captureTestNow.addingTimeInterval(offset)
            )
        ))
        if shouldThrow {
            #expect(throws: DomainCommandError.dateInFuture) { try command.validate(now: captureTestNow) }
        } else {
            #expect(throws: Never.self) { try command.validate(now: captureTestNow) }
        }
    }

    @Test("REQ-CAPTURE-021: valid commands pass their own checks")
    func validCommandsPass() throws {
        let commands: [DomainCommand] = [
            .createNote(CreateNoteCommand(rawText: "Проверить давление в шинах")),
            .recordOdometerReading(RecordOdometerReadingCommand(reading: DomainFixtures.Odometers.reading84k)),
            .confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand(
                completion: DomainFixtures.Maintenance.oilCompletionRecent
            )),
            .setMaintenancePolicy(SetMaintenancePolicyCommand(
                vehicleID: vehicleID,
                policy: DomainFixtures.Maintenance.brakeFluidPolicy
            )),
            .stopTrackingOperation(StopTrackingOperationCommand(vehicleID: vehicleID, operationID: .brakeFluid)),
            .recordVehicleEvent(RecordVehicleEventCommand(event: DomainFixtures.History.carWashEvent
                    .dated(captureTestNow))),
            .recordExpense(RecordExpenseCommand(event: DomainFixtures.History.serviceVisit)),
            .recordVehicleFact(RecordVehicleFactCommand(
                vehicleID: vehicleID,
                fact: VehicleFact(field: .year, value: "2019")
            )),
        ]
        for command in commands {
            try command.validate(now: captureTestNow)
        }
    }

    @Test("REQ-CAPTURE-021: the mapper rechecks invariants at execution time and returns no command on violation")
    func mapperRejectsInvalidCommand() throws {
        let later = captureTestNow.addingTimeInterval(3600)
        let capture = CaptureInput(payload: .text("поменял масло"), source: .pitText, capturedAt: later)
        let proposal = MemoryProposal(
            sourceInputID: capture.id,
            kind: .maintenanceCompletion,
            rawText: capture.payload.rawContent,
            extractedOperationID: .engineOilService
        )
        let context = ProposalValidationContext(vehicle: DomainFixtures.Vehicles.standard, now: later)
        let result = try validated(proposal, input: capture, context: context)
        let permit = try #require(ConfirmationPolicy().permit(for: result, userConfirmed: true))

        #expect(throws: DomainCommandMappingError.invalidCommand(.dateInFuture)) {
            try DomainCommandMapper().command(for: permit, now: captureTestNow)
        }
    }
}
