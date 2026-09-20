#if DEBUG
    import Foundation

    /// Fictional facts for smoke checks and screenshots, launched with `-pitstop-demo-data`. It always
    /// runs against an in-memory store and writes only through domain commands, like any other caller.
    enum DemoData {
        static let argument = "-pitstop-demo-data"

        static func seed(_ store: any CarMemoryStore, now: Date = Date()) async {
            func daysAgo(_ days: Double) -> Date {
                now.addingTimeInterval(-days * 86400)
            }
            guard let vehicleID = try? await store.currentVehicle().id else { return }
            let commands: [DomainCommand] = [
                .recordVehicleFact(.init(vehicleID: vehicleID, fact: VehicleFact(field: .name, value: "Arteon"))),
                .recordOdometerReading(.init(reading: OdometerReading(
                    vehicleID: vehicleID,
                    value: 59200,
                    recordedAt: now
                ))),
                .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenancePolicy(
                    operationID: .engineOilService, distanceIntervalKm: 10000, timeIntervalMonths: 12,
                    source: .userCustom
                ))),
                .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenancePolicy(
                    operationID: .dsgService, distanceIntervalKm: 60000, source: .userCustom
                ))),
                .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenancePolicy(
                    operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom
                ))),
                .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenancePolicy(
                    operationID: .cabinFilter, distanceIntervalKm: 15000, source: .userCustom
                ))),
                .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                    vehicleID: vehicleID, operationID: .engineOilService, performedAt: daysAgo(240), odometerKm: 50000
                ))),
                .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                    vehicleID: vehicleID, operationID: .dsgService, performedAt: daysAgo(1100), odometerKm: 2000
                ))),
                .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                    vehicleID: vehicleID, operationID: .brakeFluid, performedAt: daysAgo(715)
                ))),
                .recordVehicleEvent(.init(event: HistoryEvent(
                    vehicleID: vehicleID, kind: .carWash, date: daysAgo(6), odometerKm: 58900, amount: 1200
                ))),
                .createNote(CreateNoteCommand(
                    vehicleID: vehicleID,
                    rawText: "Ask about the stain on the rear seat",
                    createdAt: daysAgo(2)
                )),
                .createNote(CreateNoteCommand(
                    vehicleID: vehicleID,
                    rawText: "Left wiper streaks at speed",
                    createdAt: daysAgo(1)
                )),
            ]
            for command in commands {
                _ = try? await store.execute(command, now: now)
            }
        }
    }
#endif
