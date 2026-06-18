import SwiftData
import SwiftUI

struct NotificationScheduleView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppNavigationState.self) private var navigation
    @Query private var settingsList: [AppSettingsEntity]
    @Query private var vehicles: [VehicleConfig]
    @Query private var visits: [ServiceVisitEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]
    @State private var planned: [PlannedNotification] = []
    @State private var permissionStatus: NotificationPermissionStatus?
    private let scheduler = NotificationScheduler()
    private let themeController = ThemeController()

    private var reminderGroups: [NotificationReminderGroup] {
        NotificationReminderGrouper.groups(from: planned)
    }

    private var scheduleRefreshToken: String {
        let odometer = vehicles.first?.odometerKm ?? 0
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visits.map(VisitSnapshot.init(from:))) ?? 0
        return "\(odometer)-\(lastOil)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let permissionStatus {
                    permissionStatusSection(permissionStatus)
                }
                if reminderGroups.isEmpty {
                    Text("notifications.schedule.empty")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    Text("notifications.schedule.intro")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    ForEach(reminderGroups) { group in
                        Button {
                            TapFeedback.light()
                            navigation.open(.reminderTopic(group.topic))
                        } label: {
                            NotificationTopicCard(group: group, colorScheme: colorScheme)
                        }
                        .buttonStyle(.hapticPlain)
                    }
                    if AppConfiguration.installTestNotificationStack {
                        testStackSection
                    }
                }
            }
            .padding()
        }
        .background(themeController.screenBackground(for: colorScheme))
        .navigationTitle("notifications.schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reloadSchedule() }
        .onChange(of: scheduleRefreshToken) { _, _ in
            Task { await reloadSchedule() }
        }
        .refreshable { await reloadSchedule() }
    }

    private func permissionStatusSection(_ status: NotificationPermissionStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("notifications.schedule.permissions.title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VWCard {
                VStack(alignment: .leading, spacing: 8) {
                    permissionRow(
                        "notifications.schedule.permissions.alert",
                        enabled: status.alertEnabled
                    )
                    permissionRow(
                        "notifications.schedule.permissions.sound",
                        enabled: status.soundEnabled
                    )
                    permissionRow(
                        "notifications.schedule.permissions.badge",
                        enabled: status.badgeEnabled
                    )
                    if !status.isFullyEnabled {
                        Text("notifications.schedule.permissions.hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func permissionRow(_ title: LocalizedStringKey, enabled: Bool) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 0)
            Text(enabled ? "notifications.schedule.permissions.on" : "notifications.schedule.permissions.off")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(enabled ? Color.green : Color.orange)
        }
    }

    private var testStackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("notifications.schedule.test.title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VWCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("notifications.schedule.test.about")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("notifications.schedule.test.legend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("notifications.schedule.test.action") {
                        TapFeedback.light()
                        Task { try? await scheduler.scheduleTestStack() }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeController.actionTint(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func reloadSchedule() async {
        guard let settings = settingsList.first, let vehicle = vehicles.first else { return }
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visits.map(VisitSnapshot.init(from:)))
        let snapshot = scheduler.pendingPlan(
            settings: settings,
            vehicle: vehicle,
            insurance: insurancePolicies.first,
            lastOilOdometer: lastOil
        )
        let permissions = await NotificationPermissionStatus.load()
        await MainActor.run {
            planned = snapshot
            permissionStatus = permissions
        }
    }
}

private struct NotificationTopicCard: View {
    let group: NotificationReminderGroup
    let colorScheme: ColorScheme
    private let themeController = ThemeController()

    private var iconColor: Color {
        themeController.actionTint(for: colorScheme)
    }

    var body: some View {
        VWCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: group.topic.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(group.topic.titleKey))
                            .font(.body.weight(.semibold))
                        Text(group.topic.aboutText(from: group.items))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("notifications.schedule.when")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(group.items) { item in
                        NotificationMomentRow(item: item)
                    }
                }
                if group.repeatsAnnuallyOrMonthly {
                    Text("notifications.schedule.repeats")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct NotificationMomentRow: View {
    let item: PlannedNotification

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(item.category.scheduleMomentLabel(relatedOdometerKm: item.relatedOdometerKm))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(LocalizedFormat.dateTime(item.fireDate))
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}
