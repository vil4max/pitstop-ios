import PhotosUI
import SwiftData
import SwiftUI

struct MyCarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [VehicleConfig]
    @Query private var visits: [ServiceVisitEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]
    @State private var photoItem: PhotosPickerItem?
    @State private var showInsuranceDetail = false
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
                                    vehicle.odometerKm = newValue
                                    vehicle.odometerUpdatedAt = Date()
                                    try? modelContext.save()
                                    Task { await NotificationRefresh.apply(context: modelContext, visits: visits) }
                                }
                            ), updatedAt: vehicle.odometerUpdatedAt)
                        }
                        statusWidgets(vehicle: vehicle)
                    }
                }
                .padding()
            }
            .background(themeController.screenBackground(for: colorScheme))
            .navigationTitle("tab.myCar")
            .sheet(isPresented: $showInsuranceDetail) {
                if let insurance {
                    NavigationStack {
                        InsuranceView(policy: insurance)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                if item != nil {
                    TapFeedback.light()
                }
                Task { await loadPhoto(from: item) }
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let data = vehicle?.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image("DefaultCarHero")
                .resizable()
                .scaledToFit()
        }
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
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("myCar.changePhoto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.hapticPlain)
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
                    .gridCellColumns(insurance == nil ? 1 : 2)
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
        return CarStatusWidgetCard(
            symbol: "drop.fill",
            title: "myCar.status.oil.title",
            value: dueSoon
                ? LocalizedFormat.string("myCar.status.oil.dueSoon")
                : LocalizedFormat.string("myCar.status.oil.kmSince", kmSince),
            footnote: windowFootnote,
            attention: dueSoon
        )
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
        return Button {
            showInsuranceDetail = true
        } label: {
            CarStatusWidgetCard(
                symbol: "shield.checkered",
                title: "insurance.title",
                value: value,
                footnote: footnote,
                attention: expiringSoon
            )
        }
        .buttonStyle(.hapticPlain)
    }

    private func serviceStatusWidget(vehicle: VehicleConfig) -> some View {
        guard let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm) else {
            return CarStatusWidgetCard(
                symbol: "wrench.and.screwdriver.fill",
                title: "myCar.status.service.title",
                value: LocalizedFormat.string("myCar.status.service.none"),
                footnote: nil
            )
        }
        let kmToGo = nearest.windowFromKm.map { max($0 - vehicle.odometerKm, 0) }
            ?? MaintenanceEngine.kmRemaining(visit: nearest, odometer: vehicle.odometerKm)
        let visitTitle = visits.first(where: { $0.seedId == nearest.id })?.title
            ?? LocalizedFormat.string("service.visitTargetKm", nearest.targetOdometerKm)
        return CarStatusWidgetCard(
            symbol: "wrench.and.screwdriver.fill",
            title: "myCar.status.service.title",
            value: LocalizedFormat.string("myCar.status.service.remaining", kmToGo),
            footnote: visitTitle
        )
    }

    private func vehicleIdentity(_ vehicle: VehicleConfig) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(vehicle.make) \(vehicle.model) \(vehicle.modelYear) · \(vehicle.engineLabel)")
                .font(.title3.weight(.semibold))
            Text(LocalizedFormat.string(
                "vehicle.inServiceSince",
                LocalizedFormat.date(vehicle.purchaseDate)
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Button {
                Clipboard.copy(vehicle.vin)
            } label: {
                Text("VIN \(vehicle.vin)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visitSnapshots: [VisitSnapshot] {
        visits.map {
            VisitSnapshot(
                id: $0.seedId,
                kind: $0.kind,
                sortOrder: $0.sortOrder,
                targetOdometerKm: $0.targetOdometerKm,
                includesOilChange: $0.includesOilChange,
                isCompleted: $0.isCompleted,
                completedOdometer: $0.completedOdometer,
                windowFromKm: $0.windowFromKm,
                windowToKm: $0.windowToKm
            )
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run {
            vehicle?.photoData = data
            try? modelContext.save()
        }
    }
}
