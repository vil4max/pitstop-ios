import SwiftUI

struct SettingsView: View {
    let isStorageTemporary: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.data.section") {
                    LabeledContent("settings.data.storage") {
                        Text(isStorageTemporary ? "settings.data.storage.temporary" : "settings.data.storage.onDevice")
                    }
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
