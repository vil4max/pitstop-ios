import Foundation
@testable import Pitstop
import Testing

@Suite("History months")
struct HistoryMonthTests {
    private static let utc = TimeZone(identifier: "UTC")!
    private static let berlin = TimeZone(identifier: "Europe/Berlin")!
    private static let newYork = TimeZone(identifier: "America/New_York")!
    private static let gregorian = Calendar(identifier: .gregorian)

    /// A fixed instant written in the given zone, so every case states its own clock.
    private static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0,
        in zone: TimeZone = utc
    ) -> Date {
        var calendar = gregorian
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    private static func event(_ kind: HistoryEventKind, on date: Date, id: String? = nil) -> HistoryEvent {
        HistoryEvent(
            id: id.flatMap(UUID.init(uuidString:)) ?? UUID(),
            vehicleID: DomainFixtures.Vehicles.defaultID,
            kind: kind,
            date: date
        )
    }

    private static func completion(_ operation: MaintenanceOperationID, on date: Date) -> MaintenanceCompletion {
        MaintenanceCompletion(vehicleID: DomainFixtures.Vehicles.defaultID, operationID: operation, performedAt: date)
    }

    /// Year and month of a group's first instant, read in the zone it was grouped in.
    private static func yearMonth(_ month: HistoryMonth, in zone: TimeZone) -> [Int] {
        var calendar = gregorian
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: month.start)
        #expect(parts.day == 1 && parts.hour == 0 && parts.minute == 0, "a month starts at its first instant")
        return [parts.year!, parts.month!]
    }

    @Test("REQ-GRAMMAR-001: History is one group per calendar month, newest month first, in the timeline's order")
    func groupsByMonthNewestFirst() {
        let wash = Self.event(.carWash, on: Self.date(2026, 9, 19))
        let mileage = Self.event(.odometer, on: Self.date(2026, 9, 13))
        let oil = Self.completion(.engineOilService, on: Self.date(2026, 6, 30, 9))
        let visit = Self.event(.service, on: Self.date(2026, 6, 30, 8))
        let insurance = Self.event(.insurance, on: Self.date(2026, 5, 2))
        let timeline = HistoryTimeline(events: [insurance, visit, mileage, wash], completions: [oil])

        let months = timeline.months(calendar: Self.gregorian, timeZone: Self.utc)

        #expect(months.map { Self.yearMonth($0, in: Self.utc) } == [[2026, 9], [2026, 6], [2026, 5]])
        #expect(months.map(\.entries) == [
            [.event(wash), .event(mileage)],
            [.completion(oil), .event(visit)],
            [.event(insurance)],
        ])
        #expect(months.flatMap(\.entries) == timeline.entries, "grouping never reorders or drops an entry")
    }

    @Test("REQ-GRAMMAR-001: an empty History has no month groups")
    func emptyTimelineHasNoMonths() {
        #expect(HistoryTimeline.empty.months(calendar: Self.gregorian, timeZone: Self.utc).isEmpty)
    }

    @Test("ADR-0007: the first and last instants of a month stay in that month")
    func monthBoundaries() {
        let lastOfJune = Self.event(.carWash, on: Self.date(2026, 6, 30, 23, 59, 59, in: Self.berlin))
        let firstOfJuly = Self.event(.service, on: Self.date(2026, 7, 1, 0, 0, 0, in: Self.berlin))
        let timeline = HistoryTimeline(events: [lastOfJune, firstOfJuly], completions: [])

        let months = timeline.months(calendar: Self.gregorian, timeZone: Self.berlin)

        #expect(months.map { Self.yearMonth($0, in: Self.berlin) } == [[2026, 7], [2026, 6]])
        #expect(months.map(\.entries) == [[.event(firstOfJuly)], [.event(lastOfJune)]])
    }

    @Test("ADR-0007: the time zone passed in, not the calendar's or the device's, decides an entry's month")
    func timeZoneDecidesTheMonth() throws {
        // 22:30 UTC on 30 June is already 1 July in Berlin and still 30 June in New York.
        let lateEvening = Self.event(.carWash, on: Self.date(2026, 6, 30, 22, 30))
        let timeline = HistoryTimeline(events: [lateEvening], completions: [])
        var tokyoCalendar = Self.gregorian
        tokyoCalendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))

        let inBerlin = timeline.months(calendar: tokyoCalendar, timeZone: Self.berlin)
        let inNewYork = timeline.months(calendar: tokyoCalendar, timeZone: Self.newYork)

        #expect(inBerlin.map { Self.yearMonth($0, in: Self.berlin) } == [[2026, 7]])
        #expect(inNewYork.map { Self.yearMonth($0, in: Self.newYork) } == [[2026, 6]])
    }

    @Test("ADR-0007: entries on the same day keep the timeline's tie order, whatever order they were read in")
    func sameDayOrderIsDeterministic() {
        let day = Self.date(2026, 3, 14)
        let first = Self.event(.carWash, on: day, id: "A0000000-0000-0000-0000-000000000001")
        let second = Self.event(.purchase, on: day, id: "A0000000-0000-0000-0000-000000000002")
        let completion = Self.completion(.cabinFilter, on: day)
        let forward = HistoryTimeline(events: [first, second], completions: [completion])
        let reversed = HistoryTimeline(events: [second, first], completions: [completion])

        let months = forward.months(calendar: Self.gregorian, timeZone: Self.utc)

        #expect(months.count == 1)
        #expect(months.first?.entries == forward.entries)
        #expect(months == reversed.months(calendar: Self.gregorian, timeZone: Self.utc))
    }

    @Test("ADR-0007: a year change starts a new group: January comes before the December of the year before")
    func yearChangeStartsANewMonth() {
        let newYear = Self.event(.carWash, on: Self.date(2026, 1, 2))
        let december = Self.event(.service, on: Self.date(2025, 12, 31))
        let lastJanuary = Self.event(.insurance, on: Self.date(2025, 1, 15))
        let timeline = HistoryTimeline(events: [december, lastJanuary, newYear], completions: [])

        let months = timeline.months(calendar: Self.gregorian, timeZone: Self.utc)

        #expect(months.map { Self.yearMonth($0, in: Self.utc) } == [[2026, 1], [2025, 12], [2025, 1]])
    }

    @Test("ADR-0007: History corrects recorded events only; a completion is corrected on Service")
    func completionsAreNotEditableHere() {
        let event = Self.event(.carWash, on: Self.date(2026, 9, 19))
        let completion = Self.completion(.brakeFluid, on: Self.date(2026, 9, 1))

        #expect(HistoryEntry.event(event).editableEvent == event)
        #expect(HistoryEntry.completion(completion).editableEvent == nil)
    }

    @Test("REQ-GRAMMAR-001: the rail joins the rows of one month and stops at its first and last row")
    func railJoinsOneMonth() {
        #expect(GlyphColumnRail.joining(index: 0, count: 1).isEmpty)
        #expect(GlyphColumnRail.joining(index: 0, count: 3) == .below)
        #expect(GlyphColumnRail.joining(index: 1, count: 3) == [.above, .below])
        #expect(GlyphColumnRail.joining(index: 2, count: 3) == .above)
    }
}
