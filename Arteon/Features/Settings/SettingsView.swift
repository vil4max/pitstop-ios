import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettingsEntity]
    @Query private var visits: [ServiceVisitEntity]
    @State private var notificationDenied = false
    private let themeController = ThemeController()
    private let scheduler = NotificationScheduler()

    var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    Section("settings.appearance") {
                        Picker("settings.appearance", selection: Binding(
                            get: { settings.theme },
                            set: { newValue in
                                settings.theme = newValue
                                TapFeedback.selection()
                                try? modelContext.save()
                            }
                        )) {
                            Text("settings.theme.system").tag(AppThemeMode.system)
                            Text("settings.theme.light").tag(AppThemeMode.light)
                            Text("settings.theme.dark").tag(AppThemeMode.dark)
                        }
                    }
                    .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
                    Section("settings.notifications") {
                        ThemedToggle("settings.serviceReminders", isOn: notificationToggle(\.serviceRemindersEnabled, settings: settings))
                        ThemedToggle("settings.insuranceReminders", isOn: notificationToggle(\.insuranceRemindersEnabled, settings: settings))
                        ThemedToggle("settings.odometerReminder", isOn: notificationToggle(\.monthlyOdometerReminderEnabled, settings: settings))
                        NavigationLink("notifications.schedule.title") {
                            NotificationScheduleView()
                        }
                        .simultaneousGesture(TapGesture().onEnded { TapFeedback.light() })
                    }
                    .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
                }
                Section("settings.icloud.title") {
                    HStack {
                        Text("settings.icloud.status")
                        Spacer()
                        Text("settings.icloud.status.localOnly")
                            .foregroundStyle(.secondary)
                    }
                    Text("settings.icloud.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
                Section("about.title") {
                    Text("settings.disclaimer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .themedListRowBackground(colorScheme: colorScheme, theme: themeController)
            }
            .themedGroupedListSurface(colorScheme: colorScheme, theme: themeController)
            .themedSwitchTint(colorScheme: colorScheme, theme: themeController)
            .navigationTitle("tab.settings")
            .alert("notification.denied", isPresented: $notificationDenied) {
                Button("common.ok", role: .cancel) {}
            }
        }
    }

    private func notificationToggle(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsEntity, Bool>,
        settings: AppSettingsEntity
    ) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                try? modelContext.save()
                Task { await applyNotificationToggleChange(enabled: newValue, settings: settings, keyPath: keyPath) }
            }
        )
    }

    private func applyNotificationToggleChange(
        enabled: Bool,
        settings: AppSettingsEntity,
        keyPath: ReferenceWritableKeyPath<AppSettingsEntity, Bool>
    ) async {
        if enabled {
            let granted = (try? await scheduler.requestAuthorization()) ?? false
            if !granted {
                await MainActor.run {
                    settings[keyPath: keyPath] = false
                    try? modelContext.save()
                    notificationDenied = true
                }
                return
            }
        }
        await NotificationRefresh.apply(context: modelContext, visits: visits)
    }
}
