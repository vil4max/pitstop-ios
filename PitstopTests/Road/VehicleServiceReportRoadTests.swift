import Foundation
@testable import Pitstop
import Testing

private typealias Fixture = MaintenanceFixture

@Suite("Dashboard reading on Road")
struct VehicleServiceReportRoadTests {
    private func milestone(_ states: [MaintenanceOperationState], day: Double) throws -> RoadMilestone {
        let projection = RoadProjector().project(RoadContext(
            now: Fixture.date(day), maintenanceStates: states, calendar: Fixture.utc
        ))
        return try #require(projection.slots.first?.lead)
    }

    @Test("REQ-ROAD-026: the label names the dashboard only when the reading decided the milestone")
    func suffixOnlyWhenReportDecided() throws {
        let policy = Fixture.custom(.engineOilService, km: 15000, months: 12)
        let done = Fixture.completion(.engineOilService, km: 30000, day: 0)
        let dashboard = dashboardReport(distance: 3200, days: 45, odometer: 38800, day: 203)

        let decided = try milestone(
            dashboardStates([policy], [done], reports: [dashboard], currentKm: 38800, day: 203), day: 203
        )
        #expect(decided.isFromDashboard && decided.dimension == .time && decided.remainingDays == 45)

        let stricter = Fixture.custom(.engineOilService, km: 3000, months: 1)
        let recent = Fixture.completion(.engineOilService, km: 38000, day: 190)
        let owner = try milestone(
            dashboardStates([stricter], [recent], reports: [dashboard], currentKm: 38800, day: 203), day: 203
        )
        #expect(!owner.isFromDashboard)

        let withoutReport = try milestone(
            dashboardStates([policy], [done], reports: [], currentKm: 38800, day: 203),
            day: 203
        )
        #expect(!withoutReport.isFromDashboard)
    }

    @Test("REQ-ROAD-026: a reading-only operation is placed in its own dimension, with no conversion")
    func readingOnlyOperationIsPlaced() throws {
        let dashboard = dashboardReport(distance: 3200, odometer: 38800, day: 0)
        let lead = try milestone(dashboardStates([], reports: [dashboard], currentKm: 38800, day: 0), day: 0)
        #expect(lead.dimension == .distance && lead.remainingKm == 3200 && lead.remainingDays == nil)
        #expect(lead.isFromDashboard)
    }

    @Test("REQ-MAINT-034: every stored reading's odometer is a mileage observation, not only the newest")
    func olderReadingsAreObservations() {
        let older = dashboardReport(distance: 3200, odometer: 38800, day: 0)
        let newer = dashboardReport(days: 40, day: 5)
        let context = MaintenanceContext(now: Fixture.date(10), latestReading: nil, reports: [newer, older])
        #expect(context.mileage == .known && context.observedKm == 38800)
        let history = MileageObservation.history(readings: [], completions: [], reports: [newer, older])
        #expect(history.map(\.km) == [38800])
    }
}
