import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettingsEntity]
    private let themeController = ThemeController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let settings = settingsList.first {
                        settingsSection("settings.appearance") {
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
                            .pickerStyle(.menu)
                        }
                        settingsSection("settings.notifications") {
                            NavigationLink("notifications.schedule.title") {
                                NotificationScheduleView()
                            }
                            .font(.body)
                            .simultaneousGesture(TapGesture().onEnded { TapFeedback.light() })
                        }
                    }
                    settingsSection("settings.icloud.title") {
                        VStack(alignment: .leading, spacing: 8) {
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
                    }
                    settingsSection("about.title") {
                        Text("settings.disclaimer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .tabRootScreen(title: "tab.settings", colorScheme: colorScheme, theme: themeController)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            AppCard {
                content()
            }
        }
    }
}
