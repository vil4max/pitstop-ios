import XCTest
@testable import Arteon

final class MaintenancePlanDecodingTests: XCTestCase {
    func test_decodeMaintenancePlan_schema4_has15Visits() throws {
        let url = Bundle.main.url(forResource: "maintenance-plan", withExtension: "json")
        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let plan = try JSONDecoder().decode(MaintenancePlanDocument.self, from: data)
        XCTAssertEqual(plan.schemaVersion, 4)
        XCTAssertEqual(plan.visits.count, 15)
        XCTAssertEqual(plan.vehicle.odometerKm, 13_600)
        XCTAssertEqual(plan.calculation.regularService.nextWindowFromKm, 16_000)
        XCTAssertEqual(plan.calculation.regularService.nextWindowToKm, 18_000)
    }

    func test_dealerStatement_totalMatchesVisitsSum() throws {
        let url = Bundle.main.url(forResource: "maintenance-plan", withExtension: "json")!
        let plan = try JSONDecoder().decode(MaintenancePlanDocument.self, from: Data(contentsOf: url))
        let sum = plan.dealerStatement.arteonVisits.map(\.totalUah).reduce(0, +)
        XCTAssertEqual(plan.dealerStatement.arteonVisitsTotalUah, sum)
        XCTAssertEqual(sum, 55_650)
    }
}

final class UpgradesDecodingTests: XCTestCase {
    func test_decodeUpgrades_schema2_counts() throws {
        let url = Bundle.main.url(forResource: "upgrades", withExtension: "json")!
        let doc = try JSONDecoder().decode(UpgradesDocument.self, from: Data(contentsOf: url))
        XCTAssertEqual(doc.schemaVersion, 2)
        XCTAssertEqual(doc.items.filter { $0.status == .done }.count, 4)
        XCTAssertEqual(doc.items.filter { $0.status == .planned }.count, 3)
    }

    func test_decodeUpgrades_totalPlannedUsdIs5500() throws {
        let url = Bundle.main.url(forResource: "upgrades", withExtension: "json")!
        let doc = try JSONDecoder().decode(UpgradesDocument.self, from: Data(contentsOf: url))
        let snapshots = doc.items.map {
            UpgradeItemSnapshot(
                id: $0.id,
                title: $0.title,
                costUah: $0.costUah,
                currencyCode: $0.currencyCode ?? "UAH",
                status: $0.status,
                completedDate: $0.completedDate.flatMap(SeedDateParser.date(from:)),
                priority: $0.priority
            )
        }
        XCTAssertEqual(UpgradeTotals.totalPlannedUsd(items: snapshots), 5_500)
    }

    func test_decodeUpgrades_totalSpentIs83000() throws {
        let url = Bundle.main.url(forResource: "upgrades", withExtension: "json")!
        let doc = try JSONDecoder().decode(UpgradesDocument.self, from: Data(contentsOf: url))
        let snapshots = doc.items.map {
            UpgradeItemSnapshot(
                id: $0.id,
                title: $0.title,
                costUah: $0.costUah,
                currencyCode: $0.currencyCode ?? "UAH",
                status: $0.status,
                completedDate: $0.completedDate.flatMap(SeedDateParser.date(from:)),
                priority: $0.priority
            )
        }
        XCTAssertEqual(UpgradeTotals.totalSpentUah(items: snapshots), 83_000)
    }
}

final class InsuranceDecodingTests: XCTestCase {
    func test_decodeInsurance_hasVerificationURL() throws {
        let url = Bundle.main.url(forResource: "insurance", withExtension: "json")!
        let doc = try JSONDecoder().decode(InsuranceDocument.self, from: Data(contentsOf: url))
        XCTAssertEqual(doc.policyNumber, "238521403")
        XCTAssertTrue(doc.verificationUrl.contains("qr.eua.in.ua"))
    }
}
