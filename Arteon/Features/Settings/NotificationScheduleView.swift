import SwiftData
import SwiftUI

struct NotificationScheduleView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettingsEntity]
    @Query private var vehicles: [VehicleConfig]
    @Query private var visits: [ServiceVisitEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]
    @State private var planned: [PlannedNotification] = []
    @State private var authorizationDenied = false
    private let scheduler = NotificationScheduler()
    private let themeController = ThemeController()

    private var filledScheduleSections: [(section: NotificationScheduleSection, items: [PlannedNotification])] {
        NotificationScheduleSection.allCases.compactMap { section in
            let items = section.items(in: planned)
            guard !items.isEmpty else { return nil }
            return (section, items)
        }
    }

    var body: some View {
        List {
            if let settings = settingsList.first {
                Section("settings.notifications") {
                    ThemedToggle("settings.serviceReminders", isOn: settingsToggle(\.serviceRemindersEnabled, settings: settings))
                    ThemedToggle("settings.insuranceReminders", isOn: settingsToggle(\.insuranceRemindersEnabled, settings: settings))
                    ThemedToggle("settings.odometerReminder", isOn: settingsToggle(\.monthlyOdometerReminderEnabled, settings: settings))
                }
                .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
            }
            if planned.isEmpty {
                Section {
                    Text("notifications.schedule.empty")
                        .foregroundStyle(.secondary)
                }
                .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
            } else {
                ForEach(filledScheduleSections, id: \.section) { entry in
                    Section {
                        ForEach(entry.items) { item in
                            NotificationScheduleRow(item: item)
                        }
                    } header: {
                        Text(LocalizedStringKey(entry.section.titleKey))
                    }
                    .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
                }
            }
        }
        .themedGroupedListSurface(colorScheme: colorScheme, theme: themeController)
        .themedSwitchTint(colorScheme: colorScheme, theme: themeController)
        .navigationTitle("notifications.schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reloadSchedule() }
        .refreshable { await reloadSchedule() }
        .alert("notification.denied", isPresented: $authorizationDenied) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private func settingsToggle(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsEntity, Bool>,
        settings: AppSettingsEntity
    ) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                try? modelContext.save()
                Task { await applyToggleChange() }
            }
        )
    }

    private func reloadSchedule() async {
        guard let settings = settingsList.first, let vehicle = vehicles.first else { return }
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visits.map {
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
        })
        let snapshot = scheduler.pendingPlan(
            settings: settings,
            vehicle: vehicle,
            insurance: insurancePolicies.first,
            lastOilOdometer: lastOil
        )
        await MainActor.run { planned = snapshot }
    }

    private func applyToggleChange() async {
        guard let settings = settingsList.first else { return }
        let granted = (try? await scheduler.requestAuthorization()) ?? false
        if !granted {
            await MainActor.run { authorizationDenied = true }
            return
        }
        guard let vehicle = vehicles.first else { return }
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visits.map {
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
        })
        try? await scheduler.scheduleAll(
            settings: settings,
            vehicle: vehicle,
            insurance: insurancePolicies.first,
            lastOilOdometer: lastOil
        )
        await reloadSchedule()
    }
}

private struct NotificationScheduleRow: View {
    let item: PlannedNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.category.scheduleTitle(relatedOdometerKm: item.relatedOdometerKm))
                .font(.body.weight(.medium))
            Text(item.category.scheduleDetail(relatedDate: item.relatedDate, relatedOdometerKm: item.relatedOdometerKm))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(LocalizedFormat.dateTime(item.fireDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            if item.repeats {
                Text("notifications.schedule.repeats")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
