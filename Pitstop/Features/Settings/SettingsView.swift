import SwiftUI

struct SettingsView: View {
    let isStorageTemporary: Bool
    let analytics: AnalyticsSharing

    @Environment(\.dismiss) private var dismiss
    @State private var isSharingUsage: Bool

    init(isStorageTemporary: Bool, analytics: AnalyticsSharing) {
        self.isStorageTemporary = isStorageTemporary
        self.analytics = analytics
        _isSharingUsage = State(initialValue: analytics.isEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.data.section") {
                    LabeledContent("settings.data.storage") {
                        Text(isStorageTemporary ? "settings.data.storage.temporary" : "settings.data.storage.onDevice")
                    }
                }
                // Off until the user turns it on; turning it off also drops unsent events (ADR 0022).
                Section {
                    Toggle("settings.analytics.share", isOn: $isSharingUsage)
                } footer: {
                    Text("settings.analytics.footer")
                }
                .onChange(of: isSharingUsage) { _, isOn in
                    analytics.setEnabled(isOn)
                }
                Section("settings.about.section") {
                    LabeledContent("settings.about.version", value: Self.version)
                }
            }
            .navigationTitle("utility.settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
