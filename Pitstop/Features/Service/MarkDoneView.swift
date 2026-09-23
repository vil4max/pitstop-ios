import SwiftUI

struct MarkDoneView: View {
    let operation: MaintenanceOperationID
    /// Pit recorded this work for the entered date while the sheet was open, without what was typed here.
    var isAlreadyRecorded = false
    /// Grows each time the sheet says so; every change is announced.
    var alreadyRecordedNotices = 0
    /// The date, the odometer text, and whether the owner chose "Save anyway".
    let onConfirm: (Date, String, Bool) async -> Bool

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
                    Button("service.done.confirm") { confirm(anyway: false) }
                        .disabled(isSaving)
                        .accessibilityIdentifier("service.done.confirm")
                }
                if isAlreadyRecorded {
                    // Said in place, next to the input, so nothing typed is lost without a word (REQ-PIT-026).
                    Section {
                        Button("service.done.saveAnyway") { confirm(anyway: true) }
                            .disabled(isSaving)
                            .accessibilityIdentifier("service.done.saveAnyway")
                    } header: {
                        Text("service.done.alreadyRecorded")
                            .textCase(nil)
                    }
                }
            }
            .pitDisabledWhileSaving(isSaving)
            // VoiceOver focus stays on the confirmation and the message appears below it, so it is also spoken; "Save
            // anyway" is the next element after it (REQ-MAINT-040).
            .onChange(of: alreadyRecordedNotices) {
                AccessibilityNotification.Announcement(String(localized: "service.done.alreadyRecorded")).post()
            }
            .navigationTitle("service.markDone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func confirm(anyway: Bool) {
        Task {
            isSaving = true
            let saved = await onConfirm(date, odometer, anyway)
            isSaving = false
            if saved {
                dismiss()
            }
        }
    }
}
