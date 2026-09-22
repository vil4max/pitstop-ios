import Foundation

/// A mileage fact at a moment: an odometer reading, or a completion recorded with its mileage. These
/// are the two sources `MaintenanceContext` already reads, so the estimate counts from the same car
/// history the status does (ADR 0010, REQ-BOARD-026).
public struct MileageObservation: Hashable, Sendable {
    public let date: Date
    public let km: Double

    public init(date: Date, km: Double) {
        self.date = date
        self.km = km
    }

    /// Every mileage fact the car has, oldest first. Readings in miles convert first. A dashboard
    /// reading entered with its odometer is a mileage fact too (ADR 0035).
    public static func history(
        readings: some Sequence<OdometerReading>,
        completions: some Sequence<MaintenanceCompletion>,
        reports: [VehicleServiceReport] = []
    ) -> [MileageObservation] {
        let recorded = readings.map { MileageObservation(date: $0.recordedAt, km: $0.valueInKilometers) }
        let done = completions.compactMap { completion in
            completion.odometerKm.map { MileageObservation(date: completion.performedAt, km: Double($0)) }
        }
        let reported = reports.compactMap { report in
            report.odometerKm.map { MileageObservation(date: report.reportedAt, km: Double($0)) }
        }
        return (recorded + done + reported).sorted { ($0.date, $0.km) < ($1.date, $1.km) }
    }
}

/// Constants decided in ADR 0034. Like `RoadRules` they are product hypotheses kept in one place.
public enum MileageRateRules {
    /// Fewer daily observations than this say nothing about how the car is driven.
    public static let minimumObservations = 3
    public static let minimumSpanDays = 60
    /// Only the last year counts: a commute that changed two years ago is not this car's rate today.
    public static let windowDays = 365
    /// Two readings closer than this are one moment, not a trend; the pair merges into the next one.
    public static let mergePairsShorterThanDays = 7
    /// Above this a pair is a typo or a unit mix-up, not driving.
    public static let implausibleKmPerDay = 1500.0
    public static let minimumPairs = 2
    /// Consistency constant of the median absolute deviation for a normal distribution.
    public static let madScale = 1.4826
    public static let madMultiplier = 3.0
    /// Keeps identical rates (MAD 0) from rejecting each other.
    public static let outlierFloorShare = 0.25
    /// A range whose late bound is farther than this multiple of its early bound says nothing useful.
    public static let maximumSpreadRatio = 2.0
    /// Neither bound of an estimate may be farther ahead than this: two years out, "around March" is
    /// not a statement about this car, it is a statement about arithmetic.
    public static let maximumEstimateDaysAhead = 730
}

/// How fast the car is driven, as two deterministic readings of the same history: the typical rate
/// (median of pair rates, outliers removed) and the overall first-to-last rate, which keeps the long
/// trips the typical rate discards. Neither is ever stored (ADR 0034).
public struct MileageRate: Hashable, Sendable {
    public let typicalKmPerDay: Double
    public let overallKmPerDay: Double
    /// The day of the newest observation: the day the remaining kilometres are counted from.
    public let observedDay: Date

    public var fasterKmPerDay: Double {
        max(typicalKmPerDay, overallKmPerDay)
    }

    public var slowerKmPerDay: Double {
        min(typicalKmPerDay, overallKmPerDay)
    }
}

/// An approximate span of days a distance milestone may fall in. It is an annotation: it never places,
/// orders or clusters a milestone (REQ-ROAD-022, ADR 0008).
public struct EstimatedDateRange: Hashable, Sendable {
    public let earliest: Date
    public let latest: Date

    public init(earliest: Date, latest: Date) {
        self.earliest = earliest
        self.latest = latest
    }
}

/// Pure, deterministic derivation of a mileage rate and of the date range it implies. Same inputs,
/// same output (REQ-ROAD-003); `now` is injected and nothing here reads the clock or a store.
public enum MileageRateEstimator {
    /// `nil` whenever the history cannot support an estimate (REQ-ROAD-023).
    public static func rate(
        from observations: some Sequence<MileageObservation>,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MileageRate? {
        let daily = daily(observations, now: now, calendar: calendar)
        guard daily.count >= MileageRateRules.minimumObservations,
              let oldest = daily.first, let newest = daily.last,
              days(from: oldest.day, to: newest.day, calendar: calendar) >= MileageRateRules.minimumSpanDays,
              // The same staleness rule as Service and Road: an old car position describes no rate either.
              now.timeIntervalSince(newest.recordedAt) <= MaintenanceRules.mileageStaleAfter
        else { return nil }

        let usable = pairs(daily, calendar: calendar).filter {
            $0.km >= 0 && $0.kmPerDay <= MileageRateRules.implausibleKmPerDay
        }
        guard usable.count >= MileageRateRules.minimumPairs,
              let first = usable.first, let last = usable.last,
              let typical = typicalRate(of: usable)
        else { return nil }

        let overallDays = days(from: first.start.day, to: last.end.day, calendar: calendar)
        guard overallDays > 0 else { return nil }
        let overall = (last.end.km - first.start.km) / Double(overallDays)
        guard typical > 0, overall > 0 else { return nil }
        return MileageRate(typicalKmPerDay: typical, overallKmPerDay: overall, observedDay: newest.day)
    }

    /// The range from the faster rate to the slower one, capped by the operation's own time anchor:
    /// past it the time rule decides anyway. `nil` when the span is too wide, or either bound too far
    /// ahead, to mean anything (REQ-ROAD-023).
    public static func dateRange(
        remainingKm: Int,
        rate: MileageRate,
        timeAnchor: Date? = nil,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> EstimatedDateRange? {
        guard remainingKm > 0 else { return nil }
        let remaining = Double(remainingKm)
        let earlyDays = Int((remaining / rate.fasterKmPerDay).rounded())
        let lateDays = Int((remaining / rate.slowerKmPerDay).rounded())
        guard earlyDays <= MileageRateRules.maximumEstimateDaysAhead,
              lateDays <= MileageRateRules.maximumEstimateDaysAhead,
              Double(lateDays) <= MileageRateRules.maximumSpreadRatio * Double(earlyDays),
              let earliest = calendar.date(byAdding: .day, value: earlyDays, to: rate.observedDay),
              var latest = calendar.date(byAdding: .day, value: lateDays, to: rate.observedDay)
        else { return nil }

        if let timeAnchor {
            latest = min(latest, calendar.startOfDay(for: timeAnchor))
        }
        // The rate was read from a day that may itself be weeks old; an estimate never points backwards.
        let today = calendar.startOfDay(for: now)
        let start = max(earliest, today)
        guard latest >= start else { return nil }
        return EstimatedDateRange(earliest: start, latest: latest)
    }

    // MARK: - Steps

    private struct DailyObservation {
        let day: Date
        let km: Double
        /// The moment the day's winning observation was recorded; staleness is measured on it.
        let recordedAt: Date
    }

    private struct Pair {
        let start: DailyObservation
        let end: DailyObservation
        let days: Int

        var km: Double {
            end.km - start.km
        }

        var kmPerDay: Double {
            km / Double(days)
        }
    }

    /// One observation per calendar day in the owner's calendar, the higher value winning a day, over
    /// the last year and never from the future.
    private static func daily(
        _ observations: some Sequence<MileageObservation>,
        now: Date,
        calendar: Calendar
    ) -> [DailyObservation] {
        let start = calendar.date(
            byAdding: .day,
            value: -MileageRateRules.windowDays,
            to: calendar.startOfDay(for: now)
        )
        let horizon = now.addingTimeInterval(DomainCommandLimits.futureTolerance)
        let inWindow = observations.filter { observation in
            observation.date <= horizon && observation.date >= (start ?? .distantPast)
        }
        let byDay = Dictionary(grouping: inWindow) { calendar.startOfDay(for: $0.date) }
        return byDay.compactMap { day, sameDay -> DailyObservation? in
            guard let best = sameDay.max(by: { ($0.km, $0.date) < ($1.km, $1.date) }) else { return nil }
            return DailyObservation(day: day, km: best.km, recordedAt: best.date)
        }
        .sorted { $0.day < $1.day }
    }

    /// Consecutive pairs; a pair shorter than a week merges into the next one, so two readings a day
    /// apart cannot produce an extreme rate. A short tail extends the last pair instead.
    private static func pairs(_ daily: [DailyObservation], calendar: Calendar) -> [Pair] {
        var pairs: [Pair] = []
        guard var anchor = daily.first else { return pairs }
        for observation in daily.dropFirst() {
            let span = days(from: anchor.day, to: observation.day, calendar: calendar)
            guard span >= MileageRateRules.mergePairsShorterThanDays else { continue }
            pairs.append(Pair(start: anchor, end: observation, days: span))
            anchor = observation
        }
        if let last = daily.last, let open = pairs.last, open.end.day < last.day {
            pairs[pairs.count - 1] = Pair(
                start: open.start,
                end: last,
                days: days(from: open.start.day, to: last.day, calendar: calendar)
            )
        }
        return pairs
    }

    /// Median of the pair rates with outliers removed by a median absolute deviation threshold, then
    /// the median again. The relative floor keeps a history of identical rates intact.
    private static func typicalRate(of pairs: [Pair]) -> Double? {
        let rates = pairs.map(\.kmPerDay)
        guard let typical = median(of: rates) else { return nil }
        let deviations = rates.map { abs($0 - typical) }
        guard let mad = median(of: deviations) else { return nil }
        let threshold = max(
            MileageRateRules.madMultiplier * MileageRateRules.madScale * mad,
            MileageRateRules.outlierFloorShare * typical
        )
        let kept = rates.filter { abs($0 - typical) <= threshold }
        guard kept.count >= MileageRateRules.minimumPairs else { return nil }
        return median(of: kept)
    }

    private static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func days(from: Date, to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
