import Foundation
@testable import Pitstop
import Testing

/// The recheck rule alone, without a view model or a store: what Mark as done does with the completions Pit recorded
/// while its sheet was open.
@Suite("Mark as done recheck")
struct MarkDoneRecheckTests {
    /// UTC has no daylight-saving shifts, so every day below is exactly 24 hours.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private static let startOfToday = calendar.startOfDay(for: DomainFixtures.Odometers.baseDate)
    private static let today = day(0)

    private static func day(_ offset: Int, hour: Int = 12) -> Date {
        startOfToday.addingTimeInterval(TimeInterval(offset * 86400 + hour * 3600))
    }

    private static func pits(_ date: Date, odometerKm: Int? = nil) -> MaintenanceCompletion {
        MaintenanceCompletion(
            vehicleID: VehicleID(), operationID: .engineOilService, performedAt: date, odometerKm: odometerKm
        )
    }

    private static func recheck(
        _ recorded: [MaintenanceCompletion],
        odometerKm: Int? = nil,
        replacing prompted: Set<UUID>? = nil
    ) -> MarkDoneRecheck {
        MarkDoneRecheck(
            recorded: recorded, date: today, odometerKm: odometerKm, replacing: prompted, calendar: calendar
        )
    }

    @Test("REQ-MAINT-045: nothing recorded, or only more than a day away, is written")
    func writeWhenNothingNearby() {
        #expect(Self.recheck([]) == .write)
        #expect(Self.recheck([Self.pits(Self.day(-2)), Self.pits(Self.day(2))]) == .write)
        #expect(Self.recheck([Self.pits(Self.day(-2))], odometerKm: 85000) == .write)
    }

    @Test("REQ-MAINT-041: the same day with no odometer or the same odometer is already recorded")
    func sameDayIsAlreadyRecorded() {
        let early = Self.pits(Self.day(0, hour: 0))
        #expect(Self.recheck([early]) == .alreadyRecorded)
        let late = Self.pits(Self.day(0, hour: 23), odometerKm: 85000)
        #expect(Self.recheck([late], odometerKm: 85000) == .alreadyRecorded)
        #expect(Self.recheck([Self.pits(Self.day(0), odometerKm: 85000)]) == .alreadyRecorded)
    }

    @Test("REQ-MAINT-040: a differing entry within a day conflicts, nearest first, then newest")
    func differingEntryConflicts() {
        let otherOdometer = Self.pits(Self.day(0), odometerKm: 84000)
        #expect(Self.recheck([otherOdometer], odometerKm: 85000) == .conflict([otherOdometer]))

        let yesterday = Self.pits(Self.day(-1, hour: 23))
        #expect(Self.recheck([yesterday]) == .conflict([yesterday]))

        let todayEntry = Self.pits(Self.day(0, hour: 8), odometerKm: 84000)
        let tomorrow = Self.pits(Self.day(1, hour: 1))
        let earlierYesterday = Self.pits(Self.day(-1, hour: 9))
        let farAway = Self.pits(Self.day(-3))
        #expect(
            Self.recheck([earlierYesterday, tomorrow, farAway, todayEntry], odometerKm: 85000)
                == .conflict([todayEntry, tomorrow, earlierYesterday])
        )
    }

    @Test("REQ-MAINT-043: Replace with exactly the prompted entries replaces them")
    func replaceExactlyPrompted() {
        let entry = Self.pits(Self.day(0), odometerKm: 84000)
        #expect(Self.recheck([entry], odometerKm: 85000, replacing: [entry.id]) == .replace([entry.id]))
    }

    @Test("REQ-MAINT-052: Replace asks again when the entries changed, even for an equal same-day entry")
    func replaceAsksAgainWhenEntriesChanged() {
        let prompted = Self.pits(Self.day(0), odometerKm: 84000)
        let added = Self.pits(Self.day(-1))
        #expect(
            Self.recheck([prompted, added], odometerKm: 85000, replacing: [prompted.id])
                == .conflict([prompted, added])
        )

        let equal = Self.pits(Self.day(0), odometerKm: 85000)
        #expect(Self.recheck([equal], odometerKm: 85000, replacing: [prompted.id]) == .conflict([equal]))
    }

    @Test("REQ-MAINT-052: Replace with every prompted entry gone writes the owner's completion")
    func replaceWithNothingNearbyWrites() {
        #expect(Self.recheck([Self.pits(Self.day(-3))], replacing: [UUID()]) == .write)
    }
}
