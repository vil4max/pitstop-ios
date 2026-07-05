import XCTest
@testable import Pitstop

final class MaintenancePlanDecodingTests: XCTestCase {
    func test_decodeMaintenancePlan_schema5_has15Visits() throws {
        let url = Bundle.main.url(forResource: "maintenance-plan", withExtension: "json")
        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let plan = try JSONDecoder().decode(MaintenancePlanDocument.self, from: data)
        XCTAssertEqual(plan.schemaVersion, 5)
        XCTAssertEqual(plan.visits.count, 15)
        XCTAssertEqual(plan.vehicle.odometerKm, 13_600)
        XCTAssertEqual(plan.calculation.regularService.nextWindowFromKm, 16_000)
        XCTAssertEqual(plan.calculation.regularService.nextWindowToKm, 18_000)
    }

    func test_dealerStatement_hasThreeVehicleVisits() throws {
        let url = Bundle.main.url(forResource: "maintenance-plan", withExtension: "json")!
        let plan = try JSONDecoder().decode(MaintenancePlanDocument.self, from: Data(contentsOf: url))
        XCTAssertEqual(plan.dealerStatement.vehicleVisits.count, 3)
        XCTAssertFalse(plan.dealerStatement.otherPayments.isEmpty)
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
}

final class InsuranceDecodingTests: XCTestCase {
    func test_decodeInsurance_hasVerificationURL() throws {
        let url = Bundle.main.url(forResource: "insurance", withExtension: "json")!
        let doc = try JSONDecoder().decode(InsuranceDocument.self, from: Data(contentsOf: url))
        XCTAssertEqual(doc.policyNumber, "238521403")
        XCTAssertTrue(doc.verificationUrl.contains("qr.eua.in.ua"))
    }
}
