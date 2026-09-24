import SwiftUI

struct MarkDoneView: View {
    let operation: MaintenanceOperationID
    /// Pit recorded this work within a day of the entered date while the sheet was open, differing from what is typed
    /// here; the sheet asks which entry stays (REQ-MAINT-040).
    var conflict: MarkDoneConflict?
    /// Grows each time the sheet asks; every change is announced.
    var conflictNotices = 0
    /// The date or the odometer changed, so the prompt no longer speaks of what is entered.
    var onEdit: () -> Void = {}
    /// "Keep Pit's entry": nothing from the sheet is recorded. Returns whether the sheet closes.
    var onKeepPits: () async -> Bool = { false }
    /// The date, the odometer text, and whether the owner chose "Replace with mine".
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
                    Button("service.done.confirm") { save { await onConfirm(date, odometer, false) } }
                        .disabled(isSaving)
                        .accessibilityIdentifier("service.done.confirm")
                }
                if let conflict {
                    // One choice, in place next to the input: the same work is never recorded twice, and what was
                    // typed is dropped only by the owner's choice (REQ-MAINT-040).
                    Section {
                        Button(conflict.keepTitle) { save(onKeepPits) }
                            .disabled(isSaving)
                            .accessibilityIdentifier("service.done.keepPits")
                        Button("service.done.replaceWithMine") { save { await onConfirm(date, odometer, true) } }
                            .disabled(isSaving)
                            .accessibilityIdentifier("service.done.replaceWithMine")
                    } header: {
                        Text(conflict.message)
                            .textCase(nil)
                    }
                }
            }
            .pitDisabledWhileSaving(isSaving)
            // Leaving mid-save hands the save's result to whatever opens next (ADR 0032, REQ-NEW-11).
            .interactiveDismissDisabled(isSaving)
            // VoiceOver focus stays on the confirmation and the prompt appears below it, so it is also spoken; its two
            // choices are the next elements after it (REQ-MAINT-040).
            .onChange(of: date) { onEdit() }
            .onChange(of: odometer) { onEdit() }
            .onChange(of: conflictNotices) {
                if let conflict {
                    AccessibilityNotification.Announcement(conflict.message).post()
                }
            }
            .navigationTitle("service.markDone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
    }

    /// Runs one of the sheet's actions under the save lock and closes the sheet when it reports success.
    private func save(_ action: @escaping () async -> Bool) {
        Task {
            isSaving = true
            let saved = await action()
            isSaving = false
            if saved {
                dismiss()
            }
        }
    }
}

#if DEBUG
    #Preview("Mark as done, Pit's entry") {
        let entry = MaintenanceCompletion(
            vehicleID: VehicleID(), operationID: .engineOilService, performedAt: .now, odometerKm: 85000
        )
        MarkDoneView(operation: .engineOilService, conflict: MarkDoneConflict(pitEntries: [entry])) { _, _, _ in false }
    }

    #Preview("Mark as done, two Pit entries, dark AX") {
        let entries = [
            MaintenanceCompletion(vehicleID: VehicleID(), operationID: .engineOilService, performedAt: .now),
            MaintenanceCompletion(
                vehicleID: VehicleID(), operationID: .engineOilService, performedAt: .now - 86400, odometerKm: 84900
            ),
        ]
        MarkDoneView(operation: .engineOilService, conflict: MarkDoneConflict(pitEntries: entries)) { _, _, _ in false }
            .preferredColorScheme(.dark)
            .dynamicTypeSize(.accessibility3)
    }
#endif
