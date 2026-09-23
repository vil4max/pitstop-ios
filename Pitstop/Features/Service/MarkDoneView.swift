import SwiftUI

struct MarkDoneView: View {
    let operation: MaintenanceOperationID
    let onConfirm: (Date, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var odometer = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("service.done.date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("carEditor.odometer.placeholder", text: $odometer)
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.done.odometer")
                } header: {
                    operation.titleText
                } footer: {
                    Text("service.done.footer")
                }
                Section {
                    // The explicit confirmation: only performed work resets a cycle (core C5).
                    Button("service.done.confirm") {
                        Task {
                            isSaving = true
                            let saved = await onConfirm(date, odometer)
                            isSaving = false
                            if saved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("service.done.confirm")
                }
            }
            .pitDisabledWhileSaving(isSaving)
            .navigationTitle("service.markDone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
