import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

private func input(_ text: String) -> CaptureInput {
    CaptureInput(payload: .text(text), source: .pitText, capturedAt: now)
}

private func pipeline(_ store: FakeCarMemoryStore) -> RememberPipeline {
    RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), now: { now })
}

@Suite("Dashboard reading through Pit")
struct VehicleServiceReportCaptureTests {
    @Test(
        "REQ-MAINT-039: the rules read a dashboard countdown and never guess the operation",
        arguments: [
            ("dashboard says service in 3200 km and 45 days", nil, 3200.0, DistanceUnit.kilometers, Int?(45)),
            ("dashboard says oil service in 2 000 mi", MaintenanceOperationID.engineOilService, 2000, .miles, nil),
            ("приборка показывает сервис через 3200 км и 45 дней", nil, 3200, .kilometers, 45),
            ("dashboard says service overdue by 300 km", nil, -300, .kilometers, nil),
        ]
    )
    func rulesReadTheDashboard(
        text: String,
        operation: MaintenanceOperationID?,
        distance: Double?,
        unit: DistanceUnit,
        days: Int?
    ) async throws {
        let interpreted = try await RuleBasedInterpreter().interpret(input(text))
        let proposal = try #require(interpreted)
        #expect(proposal.kind == .vehicleServiceReport)
        #expect(proposal.extractedOperationID == operation)
        #expect(proposal.extractedRemainingDistance == distance)
        #expect(proposal.extractedRemainingDistanceUnit == unit)
        #expect(proposal.extractedRemainingDays == days)
        // The remaining distance is never read as the odometer.
        #expect(proposal.extractedOdometerKm == nil)
    }

    @Test(
        "REQ-MAINT-039: a mileage or a completion near the display keeps its own meaning",
        arguments: [
            ("машина показывает 91500 км", ProposalKind.odometerReading, 91500.0, MaintenanceOperationID?.none),
            ("dashboard shows 91500 km", .odometerReading, 91500, nil),
            ("поменял масло на 84200 км, машина пишет следующее через 15000 км", .maintenanceCompletion, 84200,
             .engineOilService),
            ("заменил лампу приборной панели, пробег 91500 км", .odometerReading, 91500, nil),
        ]
    )
    func plainMileageIsNotACountdown(
        text: String, kind: ProposalKind, kilometers: Double, operation: MaintenanceOperationID?
    ) async throws {
        let interpreted = try await RuleBasedInterpreter().interpret(input(text))
        let proposal = try #require(interpreted)
        #expect(proposal.kind == kind)
        #expect(proposal.extractedOdometerKm == kilometers)
        #expect(proposal.extractedOperationID == operation)
        #expect(proposal.extractedRemainingDistance == nil)
    }

    @Test(
        "REQ-MAINT-039: an overdue countdown is read as overdue, never as a mileage",
        arguments: [
            "приборка: ТО просрочено на 300 км",
            "ТО прострочено на 300 км",
            "ТО просрочено на 300 км",
            "dashboard says service 300 km overdue",
            "dashboard says 300 km overdue",
            "приборка показывает: просрочено на 300 км",
        ]
    )
    func overdueCountdownIsNeverAMileage(text: String) async throws {
        let interpreted = try await RuleBasedInterpreter().interpret(input(text))
        let proposal = try #require(interpreted)
        #expect(proposal.kind == .vehicleServiceReport)
        #expect(proposal.extractedRemainingDistance == -300 && proposal.extractedOdometerKm == nil)
    }

    @Test(
        "REQ-MAINT-039: overdue without a service word is no dashboard reading and never a mileage",
        arguments: [
            "insurance overdue by 10 days",
            "техосмотр просрочено на 10 дней",
            "прострочено на 300 км",
        ]
    )
    func overdueWithoutServiceKeepsWords(text: String) async throws {
        #expect(try await RuleBasedInterpreter().interpret(input(text)) == nil)
    }

    @Test("REQ-MAINT-039: other phrases that say overdue keep their earlier interpretation")
    func overdueElsewhereFallsThrough() async throws {
        let odometer = try #require(try await RuleBasedInterpreter().interpret(
            input("страховка просрочена, пробег 91500 км")
        ))
        #expect(odometer.kind == .odometerReading && odometer.extractedOdometerKm == 91500)
        let washing = try #require(try await RuleBasedInterpreter().interpret(
            input("washed the car, parking fine overdue")
        ))
        #expect(washing.kind == .vehicleEvent && washing.extractedEventKind == .carWash)
    }

    @Test("REQ-MAINT-039: an overdue value that cannot be read as a countdown keeps only the words")
    func unreadableOverdueKeepsWords() async throws {
        #expect(try await RuleBasedInterpreter().interpret(input("приборка: просрочено на 300 км пробега")) == nil)
    }

    @Test(
        "REQ-MAINT-039: a mileage beside an overdue service word stays the odometer reading",
        arguments: [
            "пробег 91500, ТО просрочено",
            "пробег 91500 км, ТО просрочено",
            "odometer 91500 km, service overdue",
            "приборка пишет просрочено, пробег 91500 км",
        ]
    )
    func mileageBesideOverdueIsTheOdometer(text: String) async throws {
        let proposal = try #require(try await RuleBasedInterpreter().interpret(input(text)))
        #expect(proposal.kind == .odometerReading && proposal.extractedOdometerKm == 91500)
    }

    @Test("REQ-MAINT-039: the particle \"то\" is not the service \"ТО\"")
    func particleIsNotAService() async throws {
        #expect(try await RuleBasedInterpreter().interpret(input("что-то просрочено на 300 км")) == nil)
        #expect(try await RuleBasedInterpreter().interpret(input("то есть просрочено на 300 км")) == nil)
    }

    @Test("REQ-MAINT-039: a number followed by пробега is the odometer, never a chained countdown value")
    func trailingMileageWordIsTheOdometer() async throws {
        let interpreted = try await RuleBasedInterpreter().interpret(
            input("приборка показывает ТО через 45 дней и 38800 км пробега")
        )
        let proposal = try #require(interpreted)
        #expect(proposal.kind == .vehicleServiceReport && proposal.extractedRemainingDays == 45)
        #expect(proposal.extractedRemainingDistance == nil && proposal.extractedOdometerKm == 38800)
    }

    @Test("REQ-MAINT-039: an odometer beside a countdown is the odometer, the marked number the remaining")
    func odometerBesideCountdown() async throws {
        let interpreted = try await RuleBasedInterpreter().interpret(
            input("пробег 38800 км, приборка показывает ТО через 3200 км")
        )
        let proposal = try #require(interpreted)
        #expect(proposal.kind == .vehicleServiceReport)
        #expect(proposal.extractedOdometerKm == 38800 && proposal.extractedRemainingDistance == 3200)
    }

    @Test("REQ-MAINT-039: replaying an old confirmation after a newer reading keeps the newer one")
    func replayKeepsNewerReading() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsConfirmation(pending) = try await flow.remember(
            input("dashboard says oil service in 45 days"), mode: .interpreted
        ) else {
            Issue.record("expected a confirmation")
            return
        }
        _ = try await flow.confirm(pending)
        let vehicleID = try await store.currentVehicle().id
        let newer = VehicleServiceReport(
            vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now + 60, remainingDays: 30
        )
        try await store.execute(.recordVehicleServiceReport(.init(report: newer)), now: now + 60)

        await #expect(throws: RememberError.alreadySaved) { try await flow.confirm(pending) }
        #expect(try await store.vehicleServiceReports().newestPerOperation[.engineOilService] == newer)
    }

    @Test("REQ-MAINT-039: days only need no odometer; a distance asks for it after the operation")
    func questionsComeOneAtATime() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsClarification(first) = try await flow.remember(
            input("dashboard says service in 3200 km and 45 days"), mode: .interpreted
        ) else {
            Issue.record("expected a question")
            return
        }
        #expect(first.question == .operationID && first.remaining == [.odometerKm])
        #expect(await store.executed.isEmpty)

        guard case let .needsClarification(second) = try await flow.answer(first, with: .operation(.engineOilService))
        else {
            Issue.record("expected the odometer question")
            return
        }
        #expect(second.question == .odometerKm && second.remaining.isEmpty)
        #expect(await store.executed.isEmpty)

        guard case let .needsConfirmation(pending) = try await flow.answer(second, with: .odometerKm(38800)) else {
            Issue.record("expected a confirmation")
            return
        }
        // Nothing is written before the owner confirms, however many answers were given.
        #expect(await store.executed.isEmpty)
        #expect(pending.content == .vehicleServiceReport(
            operationID: .engineOilService, reportedAt: now, odometerKm: 38800,
            remainingDistance: 3200, unit: .kilometers, remainingDays: 45
        ))

        let outcome = try await flow.confirm(pending)
        guard case let .saved(.vehicleServiceReportRecorded(report), preservedRaw) = outcome else {
            Issue.record("expected a saved reading, got \(outcome)")
            return
        }
        #expect(!preservedRaw && report.source == .pitCapture && report.id == pending.validated.proposal.id)
        #expect(await store.reports == [report])
        #expect(await store.completions.isEmpty)
        #expect(await store.policies.isEmpty)
    }

    @Test("REQ-MAINT-039: a reading with a named operation and days only still waits for confirmation")
    func alwaysNeedsConfirmation() async throws {
        let store = FakeCarMemoryStore()
        let outcome = try await pipeline(store).remember(
            input("dashboard says oil service in 45 days"), mode: .interpreted
        )
        guard case let .needsConfirmation(pending) = outcome else {
            Issue.record("expected a confirmation, got \(outcome)")
            return
        }
        #expect(ConfirmationPolicy().outcome(for: pending.validated) == .confirmCompact)
        #expect(ConfirmationPolicy().permit(for: pending.validated, userConfirmed: false) == nil)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-MAINT-039: cancelling at a question or at the confirmation writes nothing")
    func cancellingWritesNothing() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsClarification(question) = try await flow.remember(
            input("dashboard says service in 45 days"), mode: .interpreted
        ) else {
            Issue.record("expected a question")
            return
        }
        flow.cancel(question.input, kind: question.kind)
        #expect(await store.executed.isEmpty)

        guard case let .needsConfirmation(pending) = try await flow.answer(question, with: .operation(.cabinFilter))
        else {
            Issue.record("expected a confirmation")
            return
        }
        flow.cancel(pending.input, kind: pending.kind)
        #expect(await store.executed.isEmpty)
        #expect(await store.reports.isEmpty)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-MAINT-039: \"I don't know\" keeps the words as a note and records no reading")
    func unknownKeepsWords() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsClarification(question) = try await flow.remember(
            input("dashboard says service in 45 days"), mode: .interpreted
        ) else {
            Issue.record("expected a question")
            return
        }
        let outcome = try await flow.answer(question, with: .unknown)
        guard case .saved(.noteCreated, preservedRaw: true) = outcome else {
            Issue.record("expected the words kept, got \(outcome)")
            return
        }
        #expect(await store.reports.isEmpty)
    }

    @Test("REQ-MAINT-039: a proposal with no remaining value is incomplete, never a guess")
    func noRemainingValueIsIncomplete() {
        let capture = input("dashboard says oil service")
        let proposal = MemoryProposal(
            sourceInputID: capture.id, kind: .vehicleServiceReport, rawText: "dashboard says oil service",
            extractedOperationID: .engineOilService
        )
        let validation = ProposalValidator().validate(proposal, input: capture, context: ProposalValidationContext(
            vehicle: .provisional(), now: now
        ))
        #expect(validation == .incomplete(proposal, missing: [.remainingValue]))
        #expect(ConfirmationPolicy().outcome(for: validation) == .clarify)
    }

    @Test("REQ-MAINT-039: the mapper writes exactly one reading command carrying the unit as entered")
    func mapperWritesOneCommand() throws {
        let capture = input("dashboard says oil service in 2000 mi")
        let proposal = MemoryProposal(
            sourceInputID: capture.id, kind: .vehicleServiceReport, rawText: "dashboard says oil service in 2000 mi",
            extractedOdometerKm: 38800, extractedOperationID: .engineOilService,
            extractedRemainingDistance: 2000, extractedRemainingDistanceUnit: .miles
        )
        let checked = try validated(proposal, input: capture, context: ProposalValidationContext(
            vehicle: .provisional(), now: now
        ))
        let permit = try #require(ConfirmationPolicy().permit(for: checked, userConfirmed: true))
        let command = try DomainCommandMapper().command(for: permit, now: now)
        guard case let .recordVehicleServiceReport(record) = command else {
            Issue.record("expected a reading command, got \(command)")
            return
        }
        #expect(record.report.remainingDistance == 2000 && record.report.distanceUnit == .miles)
        #expect(record.report.odometerKm == 38800 && record.report.id == proposal.id)
    }
}
