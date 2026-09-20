import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

@Suite("Service planner")
struct ServicePlannerTests {
    private func scope(
        currentKm: Double,
        extra: [(MaintenancePolicy, MaintenanceCompletion)] = [],
        reversed: Bool = false
    ) -> SuggestedServiceScope {
        var policies = [
            Fix.custom(.engineOilService, km: 10000),
            Fix.custom(.awdCouplingService, km: 30000),
            Fix.custom(.dsgService, km: 60000),
            Fix.custom(.airFilter, km: 30000),
            Fix.custom(.cabinFilter, km: 15000),
        ] + extra.map(\.0)
        var done = [
            Fix.completion(.engineOilService, km: 50000),
            Fix.completion(.awdCouplingService, km: 30000),
            Fix.completion(.dsgService, km: 2000),
            Fix.completion(.airFilter, km: 56000),
        ] + extra.map(\.1)
        if reversed {
            policies.reverse()
            done.reverse()
        }
        return ServicePlanner().suggestedScope(
            for: Fix.states(policies, done, currentKm: currentKm, day: 10),
            context: Fix.context(done, currentKm: currentKm, day: 10)
        )
    }

    @Test("REQ-MAINT-005: every due operation is in the one suggested scope")
    func dueOperationsShareOneScope() {
        #expect(Set(scope(currentKm: 60000).due.map(\.id)) == [.engineOilService, .awdCouplingService])
    }

    @Test("REQ-MAINT-006: an operation inside the grouping window joins as due nearby; one outside does not")
    func dueNearbyJoinsScope() {
        let result = scope(currentKm: 60000)
        #expect(result.dueNearby.map(\.id) == [.dsgService])
        #expect(!result.dueNearby.contains { $0.id == .airFilter })
    }

    @Test("REQ-MAINT-006: nearby is measured from where the car is, not from the most overdue item")
    func nearbyIsMeasuredFromTheVisit() {
        let overdue = (Fix.custom(.brakeFluid, km: 30000), Fix.completion(.brakeFluid, km: 15000))
        let result = scope(currentKm: 60500, extra: [overdue])
        #expect(Set(result.due.map(\.id)) == [.brakeFluid, .engineOilService, .awdCouplingService])
        #expect(result.dueNearby.map(\.id) == [.dsgService])
    }

    @Test("REQ-MAINT-007: grouping leaves the grouped operation's own anchor unchanged")
    func groupingKeepsAnchor() {
        #expect(scope(currentKm: 60000).dueNearby.first?.anchorKm == 62000)
    }

    @Test("REQ-MAINT-016: an operation with an unknown baseline is never grouped or invented as due")
    func unknownIsNotGrouped() {
        let result = scope(currentKm: 60000)
        #expect(!(result.due + result.dueNearby).contains { $0.id == .cabinFilter })
    }

    @Test("REQ-BOARD-014: nothing due or approaching gives an empty scope, not fake urgency")
    func calmStateHasEmptyScope() {
        #expect(scope(currentKm: 51000).isEmpty)
    }

    @Test("REQ-MAINT-013: the planner returns the same scope whatever order the facts arrive in")
    func plannerIsDeterministic() {
        #expect(scope(currentKm: 60000) == scope(currentKm: 60000, reversed: true))
    }

    @Test("REQ-MAINT-014: after a partial visit the confirmed cycles reset and the skipped one stays due")
    func partialVisitKeepsSkippedOperationDue() {
        let policies = [
            Fix.custom(.engineOilService, km: 10000),
            Fix.custom(.dsgService, km: 60000),
            Fix.custom(.awdCouplingService, km: 30000),
        ]
        let done = [
            Fix.completion(.engineOilService, km: 50000),
            Fix.completion(.dsgService, km: 0),
            Fix.completion(.awdCouplingService, km: 30000),
            Fix.completion(.engineOilService, km: 60200, day: 9),
            Fix.completion(.dsgService, km: 60200, day: 9),
        ]
        let statuses = Dictionary(
            uniqueKeysWithValues: Fix.states(policies, done, currentKm: 60200, day: 10).map { ($0.id, $0.status) }
        )
        #expect(statuses == [.engineOilService: .upToDate, .dsgService: .upToDate, .awdCouplingService: .due])
    }

    @Test("ADR-0010: a visit planned by distance does not pull in work that is only near its far date anchor")
    func approachingVisitUsesDecidingDimension() {
        let policies = [Fix.custom(.engineOilService, km: 10000, months: 12), Fix.custom(.brakeFluid, months: 24)]
        let done = [Fix.completion(.engineOilService, km: 50000), Fix.completion(.brakeFluid, km: nil, day: -380)]
        let result = ServicePlanner().suggestedScope(
            for: Fix.states(policies, done, currentKm: 59000, day: 30),
            context: Fix.context(done, currentKm: 59000, day: 30)
        )
        #expect(result.due.map(\.id) == [.engineOilService])
        #expect(result.due.first?.decidedBy == .distance)
        #expect(result.dueNearby.isEmpty)
    }
}
