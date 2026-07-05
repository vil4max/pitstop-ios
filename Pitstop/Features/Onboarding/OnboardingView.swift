import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var showAddVehicle = false
    @State private var loadError: String?
    private let themeController = ThemeController()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image("DefaultVehicleHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                Text("onboarding.title")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("onboarding.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                VStack(spacing: 12) {
                    Button("onboarding.loadDemo") {
                        loadDemoData()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeController.actionTint(for: colorScheme))
                    Button("onboarding.addCar") {
                        showAddVehicle = true
                    }
                    .buttonStyle(.bordered)
                    .tint(themeController.actionTint(for: colorScheme))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeController.screenBackground(for: colorScheme))
            .sheet(isPresented: $showAddVehicle) {
                AddVehicleSheet()
            }
            .alert("common.error", isPresented: Binding(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
            )) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(loadError ?? "")
            }
        }
    }

    private func loadDemoData() {
        do {
            try PlanSeedImporter.importDemoSeed(into: modelContext)
            let vehicles = try modelContext.fetch(FetchDescriptor<VehicleConfig>())
            if let vehicle = vehicles.first {
                activeVehicleStore.select(vehicle)
            }
            Task {
                await NotificationRefresh.apply(context: modelContext)
            }
        } catch {
            loadError = String(describing: error)
        }
    }
}

struct AddVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var make = ""
    @State private var model = ""
    @State private var modelYear = Calendar.current.component(.year, from: Date())
    @State private var odometerKm = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("onboarding.field.make", text: $make)
                TextField("onboarding.field.model", text: $model)
                Stepper(value: $modelYear, in: 1980 ... modelYear + 1) {
                    Text("onboarding.field.year \(modelYear)")
                }
                Stepper(value: $odometerKm, in: 0 ... 999_999, step: 100) {
                    Text("onboarding.field.odometer \(odometerKm)")
                }
            }
            .navigationTitle("onboarding.addCar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.ok") { saveVehicle() }
                        .disabled(make.trimmingCharacters(in: .whitespaces).isEmpty || model.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveVehicle() {
        let now = Date()
        let vin = "USER-\(UUID().uuidString.prefix(8))"
        let vehicle = VehicleConfig(
            vin: vin,
            make: make.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            modelYear: modelYear,
            purchaseDate: now,
            engineLabel: "",
            odometerKm: odometerKm,
            odometerUpdatedAt: now,
            averageMonthlyMileageKm: 500,
            mileageBaselineKm: odometerKm,
            mileageBaselineMonths: 12,
            seedVersion: 0
        )
        if (try? modelContext.fetch(FetchDescriptor<AppSettingsEntity>()))?.isEmpty == true {
            modelContext.insert(AppSettingsEntity())
        }
        modelContext.insert(vehicle)
        try? modelContext.save()
        activeVehicleStore.select(vehicle)
        dismiss()
    }
}
