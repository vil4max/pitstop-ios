import Foundation
@testable import Pitstop

/// A fictional schedule for a fictional car in a fictional market (MNT-INT-002). Every name,
/// number and URL is invented: "XM" is in the ISO 3166-1 user-assigned range and the URL uses
/// the reserved `.example` domain. Real schedules never enter this public repository.
enum KestrelRecommendationFixture {
    static let make = "Example Motors"
    static let model = "Kestrel"
    static let market = "XM"
    static let engine = "2.0 petrol"
    static let transmission = "7-speed dual-clutch"
    static let drivetrain = "AWD"
    static let serviceRegime = "normal"
    static let modelYears = 2024 ... 2026

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    static let source = RecommendationSource(
        kind: .maintenanceBooklet,
        publisher: make,
        documentTitle: "Kestrel maintenance booklet (fictional)",
        edition: "XM-2024.1",
        referenceURL: URL(string: "https://kestrel.example/xm/maintenance-booklet") ?? URL(fileURLWithPath: "/"),
        licenceReference: "Fictional test fixture; no licence exists or is needed",
        retrievedAt: day(2026, 9, 22),
        verifiedBy: "MNT-INT-002 fixture author",
        verifiedAt: day(2026, 9, 22)
    )

    static func reference(_ section: String) -> SourceReference {
        SourceReference(source: source, section: section)
    }

    static let applicability = Applicability(requirements: [
        .make: .equals(make),
        .model: .equals(model),
        .modelYear: .yearWithin(modelYears),
        .market: .equals(market),
        .engine: .equals(engine),
        .transmission: .equals(transmission),
        .drivetrain: .equals(drivetrain),
        .serviceRegime: .equals(serviceRegime),
    ])

    /// Facts for a car that matches every applicability dimension.
    static let matchingFacts = VehicleFacts([
        .make: make,
        .model: model,
        .modelYear: "2025",
        .market: market,
        .engine: engine,
        .transmission: transmission,
        .drivetrain: drivetrain,
        .serviceRegime: serviceRegime,
    ])

    static let firstRegistration = day(2025, 3, 10)

    static let oilProcedure = ProcedureComposition(
        operationID: .engineOilService,
        components: [
            ProcedureComponent(id: "engineOil", name: "Engine oil", provenance: reference("4.2 Oil service, item a")),
            ProcedureComponent(id: "oilFilter", name: "Oil filter", provenance: reference("4.2 Oil service, item b")),
            ProcedureComponent(
                id: "drainPlugSeal",
                name: "Drain plug sealing ring",
                provenance: reference("4.2 Oil service, item c")
            ),
        ]
    )

    static let oil = MaintenanceRecommendationRecord(
        id: "kestrel-xm-2024.1-engineOilService",
        operationID: .engineOilService,
        rule: RecommendationRule(distanceKm: 15000, months: 12, anchoring: .completionBased),
        applicability: applicability,
        provenance: reference("4.2 Oil service"),
        procedure: oilProcedure
    )

    static let dualClutchFluid = MaintenanceRecommendationRecord(
        id: "kestrel-xm-2024.1-dsgService",
        operationID: .dsgService,
        rule: RecommendationRule(distanceKm: 60000, months: nil, anchoring: .completionBased),
        applicability: applicability,
        provenance: reference("4.5 Dual-clutch transmission fluid"),
        procedure: nil
    )

    static let couplingFluid = MaintenanceRecommendationRecord(
        id: "kestrel-xm-2024.1-awdCouplingService",
        operationID: .awdCouplingService,
        rule: RecommendationRule(distanceKm: 45000, months: 36, anchoring: .completionBased),
        applicability: applicability,
        provenance: reference("4.6 All-wheel-drive coupling fluid"),
        procedure: nil
    )

    static let brakeFluid = MaintenanceRecommendationRecord(
        id: "kestrel-xm-2024.1-brakeFluid",
        operationID: .brakeFluid,
        rule: RecommendationRule(distanceKm: nil, months: 24, anchoring: .fixedGridFromFirstRegistration),
        applicability: applicability,
        provenance: reference("4.8 Brake fluid"),
        procedure: nil
    )

    static let schedule = [oil, dualClutchFluid, couplingFluid, brakeFluid]

    /// Every string the fixture carries, for the fictional-data guard.
    static var allStrings: [String] {
        var strings = [
            source.publisher, source.documentTitle, source.edition, source.referenceURL.absoluteString,
            source.licenceReference, source.verifiedBy,
        ]
        strings += matchingFacts.values.values
        for record in schedule {
            strings += [record.id, record.provenance.section]
            strings += record.procedure?.components.flatMap { [$0.id, $0.name, $0.provenance.section] } ?? []
        }
        return strings
    }
}
