import SwiftData
import SwiftUI

struct MyCarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [VehicleConfig]
    @Query private var visits: [ServiceVisitEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]
    @Environment(AppNavigationState.self) private var navigation
    private let themeController = ThemeController()
    private let heroImageMaxHeight: CGFloat = 180

    private var vehicle: VehicleConfig? {
        vehicles.first
    }

    private var insurance: InsurancePolicyEntity? {
        insurancePolicies.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    vehicleHeader
                    if let vehicle {
                        VWCard {
                            OdometerDisplay(value: Binding(
                                get: { vehicle.odometerKm },
                                set: { newValue in
                                    NotificationRefresh.updateOdometer(
                                        vehicle: vehicle,
                                        to: newValue,
                                        context: modelContext
                                    )
                                }
                            ), updatedAt: vehicle.odometerUpdatedAt)
                        }
                        statusWidgets(vehicle: vehicle)
                    }
                }
                .padding()
            }
            .tabRootScreen(title: "tab.myCar", colorScheme: colorScheme, theme: themeController)
        }
    }

    private var heroImage: some View {
        Image("DefaultCarHero")
            .resizable()
            .scaledToFit()
    }

    private var vehicleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                heroImage
                    .frame(maxWidth: .infinity, maxHeight: heroImageMaxHeight)
                if let vehicle {
                    vehicleIdentity(vehicle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusWidgetColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
    }

    private func statusWidgets(vehicle: VehicleConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("myCar.status.section")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            LazyVGrid(columns: statusWidgetColumns, spacing: 12) {
                oilStatusWidget(vehicle: vehicle)
                if let insurance {
                    insuranceStatusWidget(policy: insurance)
                }
                serviceStatusWidget(vehicle: vehicle)
                serviceEstimateWidget(vehicle: vehicle)
            }
        }
    }

    private func oilStatusWidget(vehicle: VehicleConfig) -> some View {
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visitSnapshots)
        let kmSince = lastOil.map {
            MaintenanceEngine.kmSinceLastOil(odometer: vehicle.odometerKm, lastOilOdometer: $0)
        } ?? 0
        let dueSoon = MaintenanceEngine.oilDueSoon(kmSinceLastOil: kmSince)
        let windowFootnote = lastOil.map { lastOilOdometer in
            let window = MaintenanceEngine.nextOilWindow(lastOilOdometer: lastOilOdometer)
            return LocalizedFormat.string("service.oilWindow", window.minKm, window.maxKm)
        }
        return widgetButton(.oil) {
            CarStatusWidgetCard(
                symbol: "drop.fill",
                title: "myCar.status.oil.title",
                value: dueSoon
                    ? LocalizedFormat.string("myCar.status.oil.dueSoon")
                    : LocalizedFormat.string("myCar.status.oil.kmSince", kmSince),
                footnote: windowFootnote,
                attention: dueSoon
            )
        }
    }

    private func insuranceStatusWidget(policy: InsurancePolicyEntity) -> some View {
        let daysLeft = MaintenanceEngine.daysUntil(policy.validUntil)
        let expiringSoon = MaintenanceEngine.insuranceExpiringSoon(validUntil: policy.validUntil)
        let value = expiringSoon
            ? LocalizedFormat.string("myCar.status.insurance.daysLeft", daysLeft)
            : LocalizedFormat.string("myCar.status.insurance.active")
        let footnote = LocalizedFormat.string(
            "insurance.validUntil",
            LocalizedFormat.monthYear(policy.validUntil)
        )
        return widgetButton(.insurance) {
            CarStatusWidgetCard(
                symbol: "shield.checkered",
                title: "insurance.title",
                value: value,
                footnote: footnote,
                attention: expiringSoon
            )
        }
    }

    private func serviceStatusWidget(vehicle: VehicleConfig) -> some View {
        guard let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return widgetButton(.service) {
                CarStatusWidgetCard(
                    symbol: "wrench.and.screwdriver.fill",
                    title: "myCar.status.service.title",
                    value: LocalizedFormat.string("myCar.status.service.none"),
                    footnote: nil
                )
            }
        }
        let kmToGo = nearest.windowFromKm.map { max($0 - vehicle.odometerKm, 0) }
            ?? MaintenanceEngine.kmRemaining(visit: nearest, odometer: vehicle.odometerKm)
        let visitTitle = visits.first(where: { $0.seedId == nearest.id })?.title
            ?? LocalizedFormat.string("service.visitTargetKm", nearest.targetOdometerKm)
        return widgetButton(.service) {
            CarStatusWidgetCard(
                symbol: "wrench.and.screwdriver.fill",
                title: "myCar.status.service.title",
                value: LocalizedFormat.string("myCar.status.service.remaining", kmToGo),
                footnote: visitTitle
            )
        }
    }

    private func serviceEstimateWidget(vehicle: VehicleConfig) -> some View {
        guard let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return widgetButton(.serviceEstimate) {
                CarStatusWidgetCard(
                    symbol: "calendar",
                    title: "myCar.status.serviceEstimate.title",
                    value: LocalizedFormat.string("myCar.status.service.none"),
                    footnote: nil
                )
            }
        }
        let visitTitle = visits.first(where: { $0.seedId == nearest.id })?.title
            ?? LocalizedFormat.string("service.visitTargetKm", nearest.targetOdometerKm)
        let dueNow = MaintenanceEngine.canCompleteVisitAtOdometer(visit: nearest, odometer: vehicle.odometerKm)
            || MaintenanceEngine.isInServiceWindow(visit: nearest, odometer: vehicle.odometerKm)
        if dueNow {
            return widgetButton(.serviceEstimate) {
                CarStatusWidgetCard(
                    symbol: "calendar.badge.clock",
                    title: "myCar.status.serviceEstimate.title",
                    value: LocalizedFormat.string("myCar.status.serviceEstimate.due"),
                    footnote: visitTitle,
                    attention: true
                )
            }
        }
        let targetKm = nearest.windowFromKm ?? nearest.targetOdometerKm
        guard let estimated = MaintenanceEngine.estimatedDate(
            targetOdometerKm: targetKm,
            currentOdometerKm: vehicle.odometerKm,
            averageMonthlyKm: vehicle.averageMonthlyMileageKm
        ) else {
            return widgetButton(.serviceEstimate) {
                CarStatusWidgetCard(
                    symbol: "calendar",
                    title: "myCar.status.serviceEstimate.title",
                    value: LocalizedFormat.string("myCar.status.service.none"),
                    footnote: visitTitle
                )
            }
        }
        return widgetButton(.serviceEstimate) {
            CarStatusWidgetCard(
                symbol: "calendar",
                title: "myCar.status.serviceEstimate.title",
                value: LocalizedFormat.string(
                    "myCar.status.serviceEstimate.approx",
                    LocalizedFormat.monthYear(estimated)
                ),
                footnote: visitTitle,
                attention: MaintenanceEngine.serviceEstimateSoon(estimatedDate: estimated)
            )
        }
    }

    private func widgetButton<Content: View>(
        _ kind: CarStatusWidgetKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            TapFeedback.light()
            navigation.open(.carWidget(kind))
        } label: {
            content()
        }
        .buttonStyle(.hapticPlain)
    }

    private func vehicleIdentity(_ vehicle: VehicleConfig) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(vehicle.make) \(vehicle.model) \(vehicle.modelYear) · \(vehicle.engineLabel)")
                .font(.title3.weight(.semibold))
            Button {
                Clipboard.copy(vehicle.vin)
            } label: {
                HStack(spacing: 8) {
                    Text("VIN \(vehicle.vin)")
                        .font(.subheadline.monospaced())
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.hapticPlain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visitSnapshots: [VisitSnapshot] {
        visits.map(VisitSnapshot.init(from:))
    }

}
