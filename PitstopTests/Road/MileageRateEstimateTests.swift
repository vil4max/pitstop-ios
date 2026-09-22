import Foundation
@testable import Pitstop
import Testing

/// Every car, reading, and date in this suite is fictional.
private enum Estimate {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static func day(_ text: String, hour: Int = 12) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        return utc.date(from: components) ?? .distantPast
    }

    static func observations(_ entries: [(String, Double)]) -> [MileageObservation] {
        entries.map { MileageObservation(date: day($0.0), km: $0.1) }
    }

    /// The worked example of ADR 0034: five readings and one completion of a fictional car.
    static let workedExample = observations([
        ("2026-05-01", 40000),
        ("2026-05-31", 41300),
        ("2026-06-30", 42500),
        ("2026-07-15", 45100),
        ("2026-08-14", 46300),
        ("2026-09-13", 47560),
    ])

    static let today = day("2026-09-22")

    static func rate(_ observations: [MileageObservation], now: Date = today) -> MileageRate? {
        MileageRateEstimator.rate(from: observations, now: now, calendar: utc)
    }

    static func range(
        _ observations: [MileageObservation],
        remainingKm: Int = 4940,
        timeAnchor: Date? = nil,
        now: Date = today
    ) -> EstimatedDateRange? {
        guard let rate = rate(observations, now: now) else { return nil }
        return MileageRateEstimator.dateRange(
            remainingKm: remainingKm, rate: rate, timeAnchor: timeAnchor, now: now, calendar: utc
        )
    }
}

@Suite("Mileage rate estimate")
struct MileageRateEstimateTests {
    /// Four readings 30 days apart, 1,500 km each: every pair rate is identical.
    static let steadyFiftyPerDay = Estimate.observations([
        ("2026-06-01", 30000),
        ("2026-07-01", 31500),
        ("2026-07-31", 33000),
        ("2026-08-30", 34500),
    ])

    @Test("REQ-ROAD-022: the worked example yields the two rates and the date range of ADR 0034")
    func workedExample() throws {
        let rate = try #require(Estimate.rate(Estimate.workedExample))
        #expect(abs(rate.typicalKmPerDay - 41.0) < 0.001)
        #expect(abs(rate.overallKmPerDay - 56.0) < 0.001)
        #expect(rate.observedDay == Estimate.day("2026-09-13", hour: 0))

        let range = try #require(Estimate.range(Estimate.workedExample))
        #expect(range.earliest == Estimate.day("2026-12-10", hour: 0))
        #expect(range.latest == Estimate.day("2027-01-11", hour: 0))
    }

    @Test("REQ-ROAD-022: the road trip is rejected as an outlier and identical rates reject nothing")
    func outlierRejection() throws {
        let withoutTrip = Estimate.observations([
            ("2026-05-01", 40000),
            ("2026-05-31", 41300),
            ("2026-06-30", 42500),
            ("2026-08-14", 46300),
            ("2026-09-13", 47560),
        ])
        // The 173 km/day pair never reaches the typical rate: with and without the trip it stays the
        // everyday rate of this car, and the trip survives only in the overall rate.
        let withTrip = try #require(Estimate.rate(Estimate.workedExample))
        let trimmed = try #require(Estimate.rate(withoutTrip))
        #expect(abs(withTrip.typicalKmPerDay - trimmed.typicalKmPerDay) <= 1.5)
        #expect(withTrip.typicalKmPerDay < 60 && withTrip.overallKmPerDay > withTrip.typicalKmPerDay)

        let identical = try #require(Estimate.rate(Self.steadyFiftyPerDay))
        #expect(abs(identical.typicalKmPerDay - 50.0) < 0.1)
        #expect(abs(identical.overallKmPerDay - 50.0) < 0.1)
    }

    @Test("REQ-ROAD-023: fewer than three readings in the window give no estimate")
    func tooFewReadings() {
        let two = Estimate.observations([("2026-06-01", 40000), ("2026-09-13", 47560)])
        #expect(Estimate.rate(two) == nil)
    }

    @Test("REQ-ROAD-023: a span shorter than 60 days gives no estimate")
    func spanTooShort() {
        let short = Estimate.observations([
            ("2026-07-25", 45000),
            ("2026-08-20", 46000),
            ("2026-09-13", 47560),
        ])
        #expect(Estimate.rate(short) == nil)
    }

    @Test("REQ-ROAD-023: a newest reading older than 90 days gives no estimate")
    func staleNewestReading() throws {
        let stale = Estimate.day("2026-12-14")
        #expect(Estimate.rate(Estimate.workedExample, now: stale) == nil)
        // One day inside the staleness rule it still works, so the boundary is the only difference.
        let fresh = Estimate.day("2026-12-11")
        _ = try #require(Estimate.rate(Estimate.workedExample, now: fresh))
    }

    @Test("REQ-ROAD-023: a milestone with no kilometres left carries no estimate")
    func noRemainingKilometres() {
        #expect(Estimate.range(Estimate.workedExample, remainingKm: 0) == nil)
        #expect(Estimate.range(Estimate.workedExample, remainingKm: -200) == nil)
    }

    @Test("REQ-ROAD-023: a range wider than twice its early bound, or farther than 730 days, says nothing")
    func spreadAndHorizonGuards() {
        // 20 km/day against 60 km/day: the late bound is three times the early one.
        let uneven = Estimate.observations([
            ("2026-05-01", 40000),
            ("2026-06-15", 40900),
            ("2026-07-30", 41800),
            ("2026-09-13", 47560),
        ])
        #expect(Estimate.range(uneven, remainingKm: 4940) == nil)
        // Steady 50 km/day, but 60,000 km away: 1,200 days is past the 730-day limit.
        let steady = Self.steadyFiftyPerDay
        #expect(Estimate.range(steady, remainingKm: 60000) == nil)
        #expect(Estimate.range(steady, remainingKm: 5000) != nil)
        // The boundary itself: 36,500 km at 50 km/day is exactly 730 days and is still shown.
        #expect(Estimate.range(steady, remainingKm: 36500) != nil)
        #expect(Estimate.range(steady, remainingKm: 36550) == nil)
    }

    @Test("REQ-ROAD-023: the late bound has the same 730-day limit as the early one")
    func lateBoundIsLimitedToo() throws {
        // 38.3 km/day overall against a typical 30: the spread stays inside the ratio, and 25,000 km
        // away the early bound is inside the limit while the late bound is past it.
        let uneven = Estimate.observations([
            ("2026-05-16", 30000),
            ("2026-06-30", 31350),
            ("2026-08-14", 32700),
            ("2026-09-13", 34600),
        ])
        let rate = try #require(Estimate.rate(uneven))
        let early = Int((25000.0 / rate.fasterKmPerDay).rounded())
        let late = Int((25000.0 / rate.slowerKmPerDay).rounded())
        #expect(early <= MileageRateRules.maximumEstimateDaysAhead && late > MileageRateRules.maximumEstimateDaysAhead)
        #expect(Double(late) <= MileageRateRules.maximumSpreadRatio * Double(early))
        #expect(Estimate.range(uneven, remainingKm: 25000) == nil)
    }

    @Test("REQ-ROAD-022: the late bound is capped at the operation's time anchor")
    func timeAnchorCap() throws {
        let anchor = Estimate.day("2026-12-20")
        let capped = try #require(Estimate.range(Estimate.workedExample, timeAnchor: anchor))
        #expect(capped.earliest == Estimate.day("2026-12-10", hour: 0))
        #expect(capped.latest == Estimate.day("2026-12-20", hour: 0))
        // An anchor before the early bound leaves nothing to say: the time rule decides first.
        #expect(Estimate.range(Estimate.workedExample, timeAnchor: Estimate.day("2026-10-01")) == nil)
    }

    @Test("REQ-ROAD-022: a pair above 1,500 km/day is dropped before any rate is taken")
    func implausibleRateIsDropped() {
        // Two pairs, one of them 2,000 km/day: dropping it leaves a single usable pair, and a single
        // pair is not a rate. Without the drop the median of 50 and 2,000 would be the answer.
        let jump = Estimate.observations([
            ("2026-06-15", 30000),
            ("2026-07-15", 31500),
            ("2026-08-14", 91500),
        ])
        #expect(Estimate.rate(jump) == nil)
    }

    @Test("REQ-ROAD-023: three daily observations are the fewest an estimate is taken from")
    func threeObservationsQualify() throws {
        let three = Estimate.observations([
            ("2026-06-15", 30000),
            ("2026-07-15", 31500),
            ("2026-09-13", 34500),
        ])
        let rate = try #require(Estimate.rate(three))
        #expect(abs(rate.typicalKmPerDay - 50.0) < 0.1)
        // Two readings are covered by `tooFewReadings`; fewer than three can never leave two pairs
        // either, so the count and the pair rule are one boundary and this test pins the passing side.
    }

    @Test("REQ-ROAD-022: a negative pair is rejected and the rest of the history still decides")
    func negativePairRejected() throws {
        // 42,000 km entered as 4,200 on one day: the pair into it is negative and drops out, and the
        // pair leaving it is an outlier the MAD step removes.
        let typo = Estimate.observations([
            ("2026-05-01", 40000),
            ("2026-05-31", 41300),
            ("2026-06-30", 4200),
            ("2026-07-30", 43800),
            ("2026-08-29", 45300),
            ("2026-09-13", 46000),
        ])
        let rate = try #require(Estimate.rate(typo))
        #expect(rate.typicalKmPerDay > 0 && rate.typicalKmPerDay < 100)
        #expect(rate.overallKmPerDay > 0)
    }

    @Test("REQ-ROAD-003: the same history and moment give the same estimate every time")
    func deterministic() throws {
        let first = try #require(Estimate.range(Estimate.workedExample))
        let second = try #require(Estimate.range(Estimate.workedExample.reversed().map(\.self)))
        #expect(first == second)
    }
}
