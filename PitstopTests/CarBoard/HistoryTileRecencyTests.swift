import Foundation
@testable import Pitstop
import SwiftUI
import Testing

/// The History tile's "3 days ago" counts from the board's own moment and calendar, never from the wall clock.
@MainActor
@Suite("History tile recency")
struct HistoryTileRecencyTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Far from today, so a hidden wall clock would give another answer.
    private static let fixedNow = DomainFixtures.Odometers.baseDate

    @Test("REQ-BOARD-026: the board's moment is its injected clock and calendar, before and after a load")
    func boardCarriesItsClock() async {
        let fixedNow = Self.fixedNow
        let model = CarBoardViewModel(store: FakeCarMemoryStore(), now: { fixedNow }, calendar: Self.calendar)
        #expect(model.state.moment == Self.fixedNow)
        #expect(model.state.calendar == Self.calendar)

        await model.load()

        #expect(model.state.moment == Self.fixedNow)
        #expect(model.state.calendar == Self.calendar)
    }

    @Test("REQ-BOARD-026: day recency depends on the moment it is given, counted in whole days")
    func recencyCountsFromTheGivenMoment() {
        let event = Self.fixedNow.addingTimeInterval(-3 * 86400)
        let threeDaysLater = FeatureFormat.dayRecency(of: event, now: Self.fixedNow, calendar: Self.calendar)
        let sameDay = FeatureFormat.dayRecency(of: event, now: event, calendar: Self.calendar)
        let laterThatDay = FeatureFormat.dayRecency(
            of: event, now: Self.calendar.startOfDay(for: event).addingTimeInterval(86399), calendar: Self.calendar
        )

        #expect(threeDaysLater != sameDay)
        #expect(sameDay == laterThatDay, "the time of day does not change a day's recency")
    }
}
