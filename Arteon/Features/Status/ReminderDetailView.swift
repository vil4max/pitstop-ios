import SwiftData
import SwiftUI

struct ReminderDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationState.self) private var navigation
    @Query private var vehicles: [VehicleConfig]
    @Query(sort: \ServiceVisitEntity.sortOrder) private var visits: [ServiceVisitEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]

    let destination: AppDestination
    private let themeController = ThemeController()

    private var vehicle: VehicleConfig? { vehicles.first }
    private var insurance: InsurancePolicyEntity? { insurancePolicies.first }

    private var visitSnapshots: [VisitSnapshot] {
        visits.map(VisitSnapshot.init(from:))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    explanationCard
                    if let action = primaryAction {
                        Button(action.title) {
                            TapFeedback.light()
                            dismiss()
                            if action.focusesMyCar {
                                navigation.selectedTab = .myCar
                            } else if action.opensInsurancePolicy {
                                navigation.openInsurancePolicy()
                            } else if let destination = action.destination {
                                navigation.open(destination)
                            }
                        }
                        .buttonStyle(.hapticPlain)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeController.actionTint(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .padding()
            }
            .background(themeController.screenBackground(for: colorScheme))
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        TapFeedback.light()
                        dismiss()
                    }
                }
            }
            .themedActionTint(colorScheme: colorScheme, theme: themeController)
        }
    }

    private var titleKey: LocalizedStringKey {
        switch destination {
        case let .reminderTopic(topic):
            LocalizedStringKey(topic.titleKey)
        case let .carWidget(widget):
            widget.titleKey
        case .serviceVisit:
            "detail.serviceVisit.title"
        }
    }

    private var headerCard: some View {
        VWCard {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(statusTitle)
                        .font(.headline)
                } icon: {
                    Image(systemName: symbolName)
                        .foregroundStyle(themeController.actionTint(for: colorScheme))
                }
                Text(statusValue)
                    .font(.title3.weight(.semibold))
                if let footnote = statusFootnote {
                    Text(footnote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var explanationCard: some View {
        VWCard {
            Text(explanationKey)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct DetailAction {
        let title: LocalizedStringKey
        let destination: AppDestination?
        var opensInsurancePolicy = false
        var focusesMyCar = false

        static func navigate(_ title: LocalizedStringKey, to destination: AppDestination) -> DetailAction {
            DetailAction(title: title, destination: destination)
        }

        static func insurancePolicy() -> DetailAction {
            DetailAction(title: "detail.action.openInsurance", destination: nil, opensInsurancePolicy: true)
        }
    }

    private var primaryAction: DetailAction? {
        switch destination {
        case .reminderTopic(.odometer):
            return DetailAction(title: "detail.action.goToMyCar", destination: nil, focusesMyCar: true)
        case .reminderTopic(.oilChange), .carWidget(.oil):
            if let seedId = nearestServiceVisitSeedId {
                return .navigate("detail.action.openService", to: .serviceVisit(seedId: seedId))
            }
            return nil
        case .reminderTopic(.maintenancePlan), .reminderTopic(.seasonalTires):
            if let seedId = nearestServiceVisitSeedId {
                return .navigate("detail.action.openService", to: .serviceVisit(seedId: seedId))
            }
            return nil
        case .reminderTopic(.insurance), .carWidget(.insurance):
            return .insurancePolicy()
        case .carWidget(.service), .carWidget(.serviceEstimate), .serviceVisit:
            if let seedId = serviceVisitSeedId ?? nearestServiceVisitSeedId {
                return .navigate("detail.action.openService", to: .serviceVisit(seedId: seedId))
            }
            return nil
        }
    }

    private var serviceVisitSeedId: String? {
        if case let .serviceVisit(seedId) = destination { return seedId }
        return nil
    }

    private var nearestServiceVisitSeedId: String? {
        guard let vehicle else { return nil }
        return MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm)?.id
    }

    private var symbolName: String {
        switch destination {
        case let .reminderTopic(topic): topic.symbol
        case let .carWidget(widget): widget.symbol
        case .serviceVisit: "wrench.and.screwdriver.fill"
        }
    }

    private var statusTitle: String {
        switch destination {
        case let .reminderTopic(topic):
            return LocalizedFormat.string(String.LocalizationValue(stringLiteral: topic.titleKey))
        case let .carWidget(widget):
            return LocalizedFormat.string(String.LocalizationValue(stringLiteral: widget.statusTitleKey))
        case .serviceVisit:
            return LocalizedFormat.string("detail.serviceVisit.title")
        }
    }

    private var statusValue: String {
        guard let vehicle else { return "—" }
        switch destination {
        case .reminderTopic(.odometer):
            return LocalizedFormat.string("detail.odometer.value", vehicle.odometerKm)
        case .reminderTopic(.oilChange), .carWidget(.oil):
            let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visitSnapshots) ?? 0
            let kmSince = MaintenanceEngine.kmSinceLastOil(odometer: vehicle.odometerKm, lastOilOdometer: lastOil)
            if MaintenanceEngine.oilDueSoon(kmSinceLastOil: kmSince) {
                return LocalizedFormat.string("myCar.status.oil.dueSoon")
            }
            return LocalizedFormat.string("myCar.status.oil.kmSince", kmSince)
        case .reminderTopic(.maintenancePlan):
            return LocalizedFormat.string("notifications.topic.maintenance.about")
        case .reminderTopic(.seasonalTires):
            return seasonalStatusValue
        case .reminderTopic(.insurance), .carWidget(.insurance):
            guard let insurance else { return "—" }
            let days = MaintenanceEngine.daysUntil(insurance.validUntil)
            if MaintenanceEngine.insuranceExpiringSoon(validUntil: insurance.validUntil) {
                return LocalizedFormat.string("myCar.status.insurance.daysLeft", days)
            }
            return LocalizedFormat.string("myCar.status.insurance.active")
        case .carWidget(.service), .serviceVisit:
            return serviceKmValue(vehicle: vehicle)
        case .carWidget(.serviceEstimate):
            return serviceEstimateValue(vehicle: vehicle)
        }
    }

    private var statusFootnote: String? {
        switch destination {
        case .reminderTopic(.odometer):
            return LocalizedFormat.string("notifications.topic.odometer.about")
        case .reminderTopic(.oilChange), .carWidget(.oil):
            guard let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visitSnapshots) else { return nil }
            let window = MaintenanceEngine.nextOilWindow(lastOilOdometer: lastOil)
            return LocalizedFormat.string("service.oilWindow", window.minKm, window.maxKm)
        case .reminderTopic(.seasonalTires):
            return seasonalFootnote
        case .reminderTopic(.insurance), .carWidget(.insurance):
            guard let insurance else { return nil }
            return LocalizedFormat.string(
                "insurance.validUntil",
                LocalizedFormat.monthYear(insurance.validUntil)
            )
        case .carWidget(.service), .serviceVisit:
            return serviceVisitTitle
        case .carWidget(.serviceEstimate):
            return serviceVisitTitle
        case .reminderTopic(.maintenancePlan):
            return LocalizedFormat.string("detail.maintenance.footnote")
        }
    }

    private var explanationKey: LocalizedStringKey {
        switch destination {
        case .reminderTopic(.odometer): "detail.odometer.explanation"
        case .reminderTopic(.oilChange), .carWidget(.oil): "detail.oil.explanation"
        case .reminderTopic(.maintenancePlan): "detail.maintenance.explanation"
        case .reminderTopic(.seasonalTires): "detail.seasonal.explanation"
        case .reminderTopic(.insurance), .carWidget(.insurance): "detail.insurance.explanation"
        case .carWidget(.service), .serviceVisit: "detail.service.explanation"
        case .carWidget(.serviceEstimate): "detail.serviceEstimate.explanation"
        }
    }

    private var seasonalStatusValue: String {
        let calendar = Calendar.current
        let spring = nextSeasonalDate(month: 4, day: 1, calendar: calendar)
        let autumn = nextSeasonalDate(month: 11, day: 1, calendar: calendar)
        let next = min(spring, autumn)
        let isSpring = spring <= autumn
        let days = MaintenanceEngine.daysUntil(next)
        return isSpring
            ? LocalizedFormat.string("detail.seasonal.value.summer", max(days, 0))
            : LocalizedFormat.string("detail.seasonal.value.winter", max(days, 0))
    }

    private var seasonalFootnote: String {
        LocalizedFormat.string("notifications.topic.seasonal.about")
    }

    private func nextSeasonalDate(month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.month = month
        components.day = day
        components.hour = 10
        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
    }

    private func serviceKmValue(vehicle: VehicleConfig) -> String {
        guard let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return LocalizedFormat.string("myCar.status.service.none")
        }
        let kmToGo = nearest.windowFromKm.map { max($0 - vehicle.odometerKm, 0) }
            ?? MaintenanceEngine.kmRemaining(visit: nearest, odometer: vehicle.odometerKm)
        return LocalizedFormat.string("myCar.status.service.remaining", kmToGo)
    }

    private func serviceEstimateValue(vehicle: VehicleConfig) -> String {
        guard let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return LocalizedFormat.string("myCar.status.service.none")
        }
        let dueNow = MaintenanceEngine.canCompleteVisitAtOdometer(visit: nearest, odometer: vehicle.odometerKm)
        if dueNow {
            return LocalizedFormat.string("myCar.status.serviceEstimate.due")
        }
        let targetKm = nearest.windowFromKm ?? nearest.targetOdometerKm
        guard let estimated = MaintenanceEngine.estimatedDate(
            targetOdometerKm: targetKm,
            currentOdometerKm: vehicle.odometerKm,
            averageMonthlyKm: vehicle.averageMonthlyMileageKm
        ) else {
            return "—"
        }
        return LocalizedFormat.string("myCar.status.serviceEstimate.approx", LocalizedFormat.monthYear(estimated))
    }

    private var serviceVisitTitle: String? {
        guard let vehicle,
              let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return nil
        }
        return visits.first(where: { $0.seedId == nearest.id })?.title
            ?? LocalizedFormat.string("service.visitTargetKm", nearest.targetOdometerKm)
    }
}

private extension CarStatusWidgetKind {
    var titleKey: LocalizedStringKey {
        switch self {
        case .oil: "myCar.status.oil.title"
        case .insurance: "insurance.title"
        case .service: "myCar.status.service.title"
        case .serviceEstimate: "myCar.status.serviceEstimate.title"
        }
    }

    var statusTitleKey: String {
        switch self {
        case .oil: "myCar.status.oil.title"
        case .insurance: "insurance.title"
        case .service: "myCar.status.service.title"
        case .serviceEstimate: "myCar.status.serviceEstimate.title"
        }
    }

    var symbol: String {
        switch self {
        case .oil: "drop.fill"
        case .insurance: "shield.checkered"
        case .service: "wrench.and.screwdriver.fill"
        case .serviceEstimate: "calendar"
        }
    }
}
