import Foundation
@testable import Pitstop
import Testing

@Suite("Car Board mileage recency")
struct MileageRecencyTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 2023-11-14 12:00 UTC.
    private static let now = Date(timeIntervalSince1970: 1_699_963_200)

    private static func recency(daysAgo days: Double, now: Date = now) -> MileageRecency {
        MileageRecency(observedAt: now.addingTimeInterval(-days * 86400), now: now, calendar: calendar)
    }

    @Test(
        "REQ-BOARD-027: the age steps from today to days, weeks and months",
        arguments: [
            (0.0, MileageRecency.today),
            (0.4, .today),
            (1, .days(1)),
            (9, .days(9)),
            (13, .days(13)),
            (14, .weeks(2)),
            (20, .weeks(2)),
            (21, .weeks(3)),
            (58, .weeks(8)),
            (62, .months(2)),
            (365, .months(12)),
        ]
    )
    func ladder(daysAgo: Double, expected: MileageRecency) {
        #expect(Self.recency(daysAgo: daysAgo) == expected)
    }

    @Test("REQ-BOARD-027: days are counted in calendar days, so last night is one day ago")
    func calendarDays() {
        let justAfterMidnight = Date(timeIntervalSince1970: 1_699_920_600) // 2023-11-14 00:10 UTC
        let lateYesterday = justAfterMidnight.addingTimeInterval(-40 * 60) // 2023-11-13 23:30 UTC
        #expect(MileageRecency(observedAt: lateYesterday, now: justAfterMidnight, calendar: Self.calendar) == .days(1))
    }

    @Test("REQ-BOARD-027: months are whole calendar months, not a day count")
    func wholeMonths() throws {
        let observed = try #require(Self.calendar.date(from: DateComponents(year: 2023, month: 9, day: 14, hour: 9)))
        #expect(MileageRecency(observedAt: observed, now: Self.now, calendar: Self.calendar) == .months(2))
        let dayShort = try #require(Self.calendar.date(from: DateComponents(year: 2023, month: 9, day: 15, hour: 9)))
        #expect(MileageRecency(observedAt: dayShort, now: Self.now, calendar: Self.calendar) == .weeks(8))
    }

    @Test("REQ-BOARD-027: an observation dated ahead of the clock reads as today, never as a negative age")
    func futureObservationIsToday() {
        #expect(Self.recency(daysAgo: -2) == .today)
    }
}
