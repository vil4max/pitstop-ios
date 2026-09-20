import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

@Suite("Maintenance engine")
struct MaintenanceEngineTests {
    @Test(
        "REQ-MAINT-001: status follows the distance threshold, with the approach window at 15% of the interval",
        arguments: [
            (58499.0, MaintenanceStatus.upToDate),
            (58500, .approaching),
            (58501, .approaching),
            (59999, .approaching),
            (60000, .due),
            (60001, .due),
        ]
    )
    func distanceBoundaries(currentKm: Double, expected: MaintenanceStatus) throws {
        let done = [Fix.completion(.engineOilService, km: 50000)]
        let state = try #require(Fix.states([Fix.oil10k], done, currentKm: currentKm, day: 10).first)
        #expect(state.status == expected)
        #expect(state.anchorKm == 60000)
        #expect(state.remainingKm == Int(60000 - currentKm))
    }

    @Test(
        "REQ-MAINT-001: the time rule has the same boundaries as the distance rule",
        arguments: [
            (310.0, MaintenanceStatus.upToDate),
            (312, .approaching),
            (365, .approaching),
            (366, .due),
            (367, .due),
        ]
    )
    func timeBoundaries(day: Double, expected: MaintenanceStatus) throws {
        let done = [Fix.completion(.brakeFluid, km: nil)]
        let state = try #require(Fix.states([Fix.custom(.brakeFluid, months: 12)], done, currentKm: nil, day: day)
            .first)
        #expect(state.status == expected)
        #expect(state.distanceBlock == nil)
    }

    @Test("REQ-MAINT-016: a known policy without a completion is unknown and produces no numbers")
    func unknownBaseline() throws {
        let state = try #require(Fix.states([Fix.oil10k], [], currentKm: 250_000, day: 900).first)
        #expect(state.status == .unknown)
        #expect(state.anchorKm == nil && state.remainingKm == nil && state.remainingFraction == nil)
    }

    @Test("REQ-MAINT-002: with distance or time, the first threshold reached makes the operation due")
    func firstThresholdWins() throws {
        let policy = DomainFixtures.Maintenance.standardOilPolicy
        let done = [Fix.completion(.engineOilService, km: 50000)]
        let byTime = try #require(Fix.states([policy], done, currentKm: 52000, day: 366).first)
        #expect(byTime.status == .due && byTime.decidedBy == .time)
        #expect(try #require(byTime.remainingKm) > 0)

        let byDistance = try #require(Fix.states([policy], done, currentKm: 65000, day: 30).first)
        #expect(byDistance.status == .due && byDistance.decidedBy == .distance)
        #expect(try #require(byDistance.remainingDays) > 0)
    }

    @Test("REQ-MAINT-003: the next anchor is the completion mileage plus the owner's interval")
    func ownerIntervalDerivesAnchor() throws {
        let done = [Fix.completion(.engineOilService, km: 12300)]
        let state = try #require(Fix.states([Fix.custom(.engineOilService, km: 7500)], done, currentKm: 13000, day: 5)
            .first)
        #expect(state.anchorKm == 19800)
    }

    @Test("REQ-MAINT-018: an early completion rebaselines from the actual mileage and only its own cycle")
    func earlyCompletionRebaselines() {
        let result = Fix.states(
            [Fix.custom(.engineOilService, km: 7500), Fix.custom(.dsgService, km: 60000)],
            [
                Fix.completion(.engineOilService, km: 12300),
                Fix.completion(.engineOilService, km: 18900, day: 200),
                Fix.completion(.dsgService, km: 10000),
            ],
            currentKm: 19000,
            day: 201
        )
        let anchors = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0.anchorKm) })
        #expect(anchors == [.engineOilService: 26400, .dsgService: 70000])
    }

    @Test("REQ-MAINT-004: completing one operation never changes another operation's state")
    func cyclesAreIndependent() {
        let policies = [Fix.oil10k, Fix.custom(.dsgService, km: 60000)]
        let base = [Fix.completion(.engineOilService, km: 50000), Fix.completion(.dsgService, km: 10000)]
        let before = Fix.states(policies, base, currentKm: 69000, day: 10)
        let after = Fix.states(
            policies,
            base + [Fix.completion(.engineOilService, km: 69000, day: 9)],
            currentKm: 69000,
            day: 10
        )
        #expect(before.first { $0.id == .dsgService } == after.first { $0.id == .dsgService })
        #expect(before.first { $0.id == .engineOilService }?.status == .due)
        #expect(after.first { $0.id == .engineOilService }?.status == .upToDate)
    }

    @Test("REQ-BOARD-006: without any mileage observation a distance rule is blocked, never computed from zero")
    func missingMileageBlocksDistance() throws {
        let done = MaintenanceCompletion(
            vehicleID: Fix.vehicleID,
            operationID: .engineOilService,
            performedAt: Fix.start,
            odometerKm: 50000
        )
        // The completion's own mileage is 400 days old, so nothing current is known.
        let state = try #require(Fix.states([Fix.oil10k], [done], currentKm: nil, day: 400).first)
        #expect(state.status == .unknown)
        #expect(state.distanceBlock == .mileageStale)
        #expect(state.remainingKm == nil && state.anchorKm == 60000)
    }

    @Test("ADR-0010: stale mileage blocks the distance rule, and a calm time status is marked partial")
    func staleMileageIsPartial() throws {
        let done = Fix.completion(.engineOilService, km: 50000)
        let context = MaintenanceContext(
            now: Fix.date(200),
            latestReading: Fix.reading(59000, day: 100),
            completions: [done]
        )
        #expect(context.mileage == .stale)
        let state = try #require(MaintenanceEngine().states(
            policies: [DomainFixtures.Maintenance.standardOilPolicy],
            completions: [done],
            context: context,
            calendar: Fix.utc
        ).first)
        #expect(state.distanceBlock == .mileageStale && state.remainingKm == nil)
        // The time rule still decides, but the state admits it is only half the picture (core C2).
        #expect(state.status == .upToDate && state.isPartial)
        #expect(state.remainingDays != nil)
    }

    @Test(
        "ADR-0008: mileage is stale strictly after 90 days",
        arguments: [(90.0, MileageKnowledge.known), (90.01, .stale)]
    )
    func staleBoundary(ageDays: Double, expected: MileageKnowledge) {
        let context = MaintenanceContext(now: Fix.date(ageDays), latestReading: Fix.reading(50000, day: 0))
        #expect(context.mileage == expected)
    }

    @Test("REQ-MAINT-016: a completion without mileage cannot anchor a distance rule, and the reason says so")
    func completionWithoutMileage() throws {
        let done = [Fix.completion(.engineOilService, km: nil)]
        let state = try #require(Fix.states([Fix.oil10k], done, currentKm: 90000, day: 10).first)
        #expect(state.status == .unknown)
        #expect(state.anchorKm == nil && state.distanceBlock == .completionMileageMissing)
    }

    @Test("ADR-0010: a completion mileage above the latest reading is itself the car's newest mileage")
    func completionMileageIsAnObservation() throws {
        let done = Fix.completion(.engineOilService, km: 70000, day: 60)
        let context = MaintenanceContext(
            now: Fix.date(60),
            latestReading: Fix.reading(68500, day: 0),
            completions: [done]
        )
        let state = try #require(MaintenanceEngine().states(
            policies: [Fix.oil10k],
            completions: [done],
            context: context,
            calendar: Fix.utc
        ).first)
        #expect(context.observedKm == 70000)
        #expect(state.anchorKm == 80000 && state.remainingKm == 10000 && state.remainingFraction == 1)
    }

    @Test("ADR-0010: half a day either side of the anchor reads as zero days, so text follows the status")
    func dayRoundingIsTowardZero() throws {
        let policy = Fix.custom(.brakeFluid, months: 12)
        let done = [Fix.completion(.brakeFluid, km: nil)]
        let before = try #require(Fix.states([policy], done, currentKm: nil, day: 365.5).first)
        let after = try #require(Fix.states([policy], done, currentKm: nil, day: 366.5).first)
        #expect(before.remainingDays == 0 && before.status == .approaching)
        #expect(after.remainingDays == 0 && after.status == .due)
    }

    @Test("REQ-MAINT-022: the same facts give the same states in the same order, regardless of input order")
    func engineIsDeterministic() {
        let policies = [Fix.oil10k, DomainFixtures.Maintenance.brakeFluidPolicy]
        let done = [Fix.completion(.engineOilService, km: 50000), Fix.completion(.brakeFluid, km: 40000)]
        let forward = Fix.states(policies, done, currentKm: 55000, day: 40)
        #expect(forward == Fix.states(policies.reversed(), done.reversed(), currentKm: 55000, day: 40))
    }

    @Test("REQ-DOMAIN-006: a custom policy is the effective one while the recommendation stays on record")
    func customPolicyIsEffective() throws {
        let policies = [DomainFixtures.Maintenance.standardOilPolicy, DomainFixtures.Maintenance.severeOilPolicy]
        let done = [Fix.completion(.engineOilService, km: 50000)]
        let state = try #require(Fix.states(policies, done, currentKm: 51000, day: 10).first)
        #expect(state.policy == DomainFixtures.Maintenance.severeOilPolicy)
        #expect(state.anchorKm == 57500)
    }

    @Test("ADR-0010: the summary talks about the most urgent known operation, else the first tracked one")
    func summarySubject() {
        #expect(Fix.states([Fix.oil10k], [], currentKm: 1000, day: 1).summarySubject?.status == .unknown)
        let mixed = Fix.states(
            [Fix.oil10k, DomainFixtures.Maintenance.brakeFluidPolicy],
            [Fix.completion(.engineOilService, km: 50000)],
            currentKm: 51000,
            day: 1
        )
        #expect(mixed.summarySubject?.id == .engineOilService)
        #expect([MaintenanceOperationState]().summarySubject == nil)
    }
}
