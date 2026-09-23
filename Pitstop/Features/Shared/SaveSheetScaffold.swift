import Observation
import SwiftUI

/// One sheet's save in flight. While it runs, Save stays disabled and Pit in the sheet is disabled too
/// (REQ-PIT-026); a sheet that locks also keeps Cancel and swipe-to-dismiss from leaving mid-save (ADR 0032).
@MainActor
@Observable
final class SheetSave {
    private(set) var isSaving = false

    /// Runs `save` unless one is already in flight, and returns whether it saved.
    func run(_ save: @MainActor () async -> Bool) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        return await save()
    }
}

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
    @State private var saving = SheetSave()

    var body: some View {
        NavigationStack {
            content
                .interactiveDismissDisabled(locksWhileSaving && saving.isSaving)
                .pitDisabledWhileSaving(saving.isSaving)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel", role: .cancel) { dismiss() }
                            .disabled(locksWhileSaving && saving.isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.save") {
                            Task {
                                if await saving.run(save) {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(saving.isSaving || !canSave)
                        .accessibilityIdentifier(saveIdentifier)
                    }
                }
        }
    }
}
