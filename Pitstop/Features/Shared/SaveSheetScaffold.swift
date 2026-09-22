import SwiftUI

/// Editor sheet grammar: an inline title, Cancel, and a Save that stays disabled while saving.
/// The sheet closes only after `save` reports success; on failure the input stays for another try
/// (REQ-CAPTURE-009).
struct SaveSheetScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let saveIdentifier: String
    var canSave = true
    /// Also blocks Cancel and swipe-to-dismiss mid-save, for a sheet where leaving would store what the
    /// owner cancelled or leave its failure behind (ADR 0032).
    var locksWhileSaving = false
    @ViewBuilder let content: Content
    let save: @MainActor () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            content
                .interactiveDismissDisabled(locksWhileSaving && isSaving)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel", role: .cancel) { dismiss() }
                            .disabled(locksWhileSaving && isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.save") {
                            Task {
                                isSaving = true
                                let saved = await save()
                                isSaving = false
                                if saved {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(isSaving || !canSave)
                        .accessibilityIdentifier(saveIdentifier)
                    }
                }
        }
    }
}
