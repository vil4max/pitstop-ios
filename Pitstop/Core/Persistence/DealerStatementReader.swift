import Foundation

enum DealerStatementReader {
    private static var cachedPlan: MaintenancePlanDocument?

    static func loadPlan() throws -> MaintenancePlanDocument {
        if let cachedPlan {
            return cachedPlan
        }
        let plan = try BundleJSONLoader.load(MaintenancePlanDocument.self, resource: "maintenance-plan")
        cachedPlan = plan
        return plan
    }

    static func dealerStatement() throws -> DealerStatementDTO {
        try loadPlan().dealerStatement
    }
}
