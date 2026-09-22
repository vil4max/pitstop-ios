import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1
private typealias ReportRecord = PitstopSchemaV4.VehicleServiceReportRecord

/// The widget's only access to the car memory (ADR 0036): a read-only container, the maintenance
/// records Service reads, mapped to domain values, and nothing else. Notes, History and plans are
/// never fetched, and there is no path to `save()`: the configuration refuses it.
enum NextServiceStoreReader {
    enum ReadError: Error, Equatable {
        case storeUnavailable
    }

    /// Opens, reads and closes the store in one call, so the extension holds no container between
    /// timeline requests and its memory stays at a few records.
    static func facts(at storeURL: URL) throws -> NextServiceFacts {
        let context: ModelContext
        do {
            context = try ModelContext(PersistenceContainer.makeReadOnly(storeURL: storeURL))
        } catch {
            throw ReadError.storeUnavailable
        }
        do {
            var vehicles = FetchDescriptor<Schema1.VehicleRecord>()
            vehicles.fetchLimit = 1
            let hasVehicle = try !context.fetch(vehicles).isEmpty
            guard hasVehicle else { return .noCar }
            return try NextServiceFacts(
                hasVehicle: true,
                // The store's own order, so the engine sees exactly what Service sees.
                policies: context
                    .fetch(FetchDescriptor(sortBy: [SortDescriptor(\Schema1.MaintenancePolicyRecord.operationID)]))
                    .map(\.domain),
                completions: context.fetch(FetchDescriptor<Schema1.MaintenanceCompletionRecord>()).map(\.domain),
                reports: context.fetch(FetchDescriptor<ReportRecord>()).map(\.domain),
                latestReading: context.fetch(FetchDescriptor<Schema1.OdometerReadingRecord>())
                    .compactMap(\.domain).latest
            )
        } catch {
            throw ReadError.storeUnavailable
        }
    }
}
