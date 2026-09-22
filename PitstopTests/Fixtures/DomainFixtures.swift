import Foundation
@testable import Pitstop

public enum DomainFixtures {

    // MARK: - Vehicles & Odometers

    public enum Vehicles {
        public static let defaultID = VehicleID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        public static let secondaryID = VehicleID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)

        public static let standard = Vehicle(
            id: defaultID,
            name: "Kestrel",
            make: "Example Motors",
            model: "Kestrel",
            year: 2019,
            // Fictional: a VIN never contains I, O or Q, so this can never match a real car.
            vin: "XMKESTRELQ0000001"
        )

        public static let unconfigured = Vehicle(
            id: secondaryID,
            name: "Моя машина"
        )
    }

    public enum Odometers {
        public static let baseDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14

        public static let reading84k = OdometerReading(
            id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
            vehicleID: Vehicles.defaultID,
            value: 84200,
            unit: .kilometers,
            recordedAt: baseDate,
            source: .manualEntry
        )

        public static let reading85k = OdometerReading(
            id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
            vehicleID: Vehicles.defaultID,
            value: 85500,
            unit: .kilometers,
            recordedAt: baseDate.addingTimeInterval(86400 * 30),
            source: .pitCapture
        )

        public static let readingMiles = OdometerReading(
            id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
            vehicleID: Vehicles.defaultID,
            value: 50000,
            unit: .miles,
            recordedAt: baseDate,
            source: .detected
        )
    }

    // MARK: - Maintenance Operations, Policies & Completions

    public enum Maintenance {
        public static let standardOilPolicy = MaintenancePolicy(
            operationID: .engineOilService,
            distanceIntervalKm: 15000,
            timeIntervalMonths: 12,
            source: .defaultRecommendation
        )

        public static let severeOilPolicy = MaintenancePolicy(
            operationID: .engineOilService,
            distanceIntervalKm: 7500,
            timeIntervalMonths: 6,
            source: .userCustom
        )

        public static let brakeFluidPolicy = MaintenancePolicy(
            operationID: .brakeFluid,
            distanceIntervalKm: nil,
            timeIntervalMonths: 24,
            source: .defaultRecommendation
        )

        public static let oilCompletionRecent = MaintenanceCompletion(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
            vehicleID: Vehicles.defaultID,
            operationID: .engineOilService,
            performedAt: Odometers.baseDate,
            odometerKm: 84200
        )

        public static let brakeFluidCompletion = MaintenanceCompletion(
            id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
            vehicleID: Vehicles.defaultID,
            operationID: .brakeFluid,
            performedAt: Odometers.baseDate.addingTimeInterval(-86400 * 365),
            odometerKm: 70000
        )
    }

    // MARK: - Notes & History

    public enum Notes {
        public static let rawThought = Note(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!,
            vehicleID: Vehicles.defaultID,
            rawText: "Кажется, левый дворник начал полосить на скорости",
            createdAt: Odometers.baseDate,
            status: .active,
            canonicalContexts: []
        )

        public static let archivedNote = Note(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!,
            vehicleID: Vehicles.defaultID,
            rawText: "Купить зимнюю омывайку -25",
            createdAt: Odometers.baseDate.addingTimeInterval(-86400 * 10),
            status: .archived,
            canonicalContexts: [.shopping]
        )

        public static let contextualWash = Note(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000003")!,
            vehicleID: Vehicles.defaultID,
            rawText: "Помыть кузов перед полировкой",
            createdAt: Odometers.baseDate,
            status: .active,
            canonicalContexts: [.carWash]
        )
    }

    public enum History {
        public static let serviceVisit = HistoryEvent(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!,
            vehicleID: Vehicles.defaultID,
            kind: .service,
            date: Odometers.baseDate,
            odometerKm: 84200,
            amount: 12500,
            note: "Замена масла и фильтра в клубном сервисе"
        )

        public static let carWashEvent = HistoryEvent(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000002")!,
            vehicleID: Vehicles.defaultID,
            kind: .carWash,
            date: Odometers.baseDate.addingTimeInterval(86400 * 5),
            odometerKm: 84400,
            amount: 1200,
            note: "Комплексная мойка"
        )
    }

    // MARK: - Capture Pipeline

    public enum Capture {
        public static let rawVoiceInput = CaptureInput(
            id: UUID(uuidString: "E0000000-0000-0000-0000-000000000001")!,
            payload: .transcript("Заменил масло и масляный фильтр на пробеге 85000"),
            source: .pitVoice,
            capturedAt: Odometers.baseDate,
            localeIdentifier: "ru_RU",
            selectedVehicleID: Vehicles.defaultID
        )

        public static let rawTextInput = CaptureInput(
            id: UUID(uuidString: "E0000000-0000-0000-0000-000000000002")!,
            payload: .text("Стук в подвеске справа спереди при проезде лежачих"),
            source: .pitText,
            capturedAt: Odometers.baseDate,
            localeIdentifier: "ru_RU",
            selectedVehicleID: Vehicles.defaultID
        )

        public static let widgetOdometerInput = CaptureInput(
            id: UUID(uuidString: "E0000000-0000-0000-0000-000000000003")!,
            payload: .text("85500"),
            source: .widget,
            capturedAt: Odometers.baseDate,
            localeIdentifier: "ru_RU",
            selectedVehicleID: Vehicles.defaultID
        )

        public static let validOdometerProposal = MemoryProposal(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!,
            sourceInputID: widgetOdometerInput.id,
            kind: .odometerReading,
            rawText: "85500",
            confidence: 0.98,
            extractedOdometerKm: 85500
        )

        public static let oilCompletionProposal = MemoryProposal(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000002")!,
            sourceInputID: rawVoiceInput.id,
            kind: .maintenanceCompletion,
            rawText: "Заменил масло и масляный фильтр на пробеге 85000",
            confidence: 0.95,
            extractedOdometerKm: 85000,
            extractedOperationID: .engineOilService
        )

        public static let ambiguousProposal = MemoryProposal(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000003")!,
            sourceInputID: rawTextInput.id,
            kind: .rawNote,
            rawText: "Стук в подвеске справа спереди при проезде лежачих",
            confidence: nil
        )
    }
}
