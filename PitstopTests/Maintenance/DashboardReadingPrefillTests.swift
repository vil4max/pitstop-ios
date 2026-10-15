import Foundation
@testable import Pitstop
import Testing

/// The dashboard sheet prefills the odometer from a reading of the same day only, a day in the owner's calendar.
@MainActor
@Suite("Dashboard reading odometer prefill")
struct DashboardReadingPrefillTests {
    /// 23:00 UTC: already the next day three hours east.
    private static let readAt = MaintenanceFixture.utc.startOfDay(for: DomainFixtures.Odometers.baseDate)
        .addingTimeInterval(23 * 3600)
    /// 01:00 UTC on the following day.
    private static let openedAt = readAt.addingTimeInterval(2 * 3600)

    private static func calendar(hoursFromUTC hours: Int) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: hours * 3600))
        return calendar
    }

    private static func service(now: Date, calendar: Calendar) async throws -> ServiceViewModel {
        let store = FakeCarMemoryStore()
        let reading = OdometerReading(vehicleID: await store.vehicle.id, value: 84200, recordedAt: readAt)
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: readAt)
        let model = ServiceViewModel(store: store, now: { now }, calendar: calendar)
        await model.load()
        return model
    }

    @Test("ADR-0035: a reading from earlier the same day prefills the odometer")
    func sameDayReadingPrefills() async throws {
        let model = try await Self.service(now: Self.readAt + 1800, calendar: Self.calendar(hoursFromUTC: 0))
        #expect(model.state.sameDayOdometerKm == 84200)
    }

    @Test("ADR-0035: the day boundary is the injected calendar's, not the device's")
    func dayBoundaryFollowsTheCalendar() async throws {
        let utc = try await Self.service(now: Self.openedAt, calendar: Self.calendar(hoursFromUTC: 0))
        #expect(utc.state.sameDayOdometerKm == nil, "yesterday's reading in UTC: the car has moved since")

        let east = try await Self.service(now: Self.openedAt, calendar: Self.calendar(hoursFromUTC: 3))
        #expect(east.state.sameDayOdometerKm == 84200, "both moments fall on one day three hours east")
    }
}
