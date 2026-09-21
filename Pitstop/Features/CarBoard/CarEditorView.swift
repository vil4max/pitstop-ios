import SwiftUI

/// One optional sheet, not a setup step: every field may stay empty, and empty means unchanged.
struct CarEditorView: View {
    let car: ProvisionalCarContext
    let onSave: (_ name: String, _ odometer: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var odometer: String
    @State private var isSaving = false

    init(car: ProvisionalCarContext, onSave: @escaping (_ name: String, _ odometer: String) async -> Bool) {
        self.car = car
        self.onSave = onSave
        _name = State(initialValue: car.isProvisional ? "" : car.name)
        _odometer = State(initialValue: car.odometerKm.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("carEditor.name.section") {
                    TextField("carEditor.name.placeholder", text: $name)
                        .textInputAutocapitalization(.words)
                        .pitReportsEditing()
                        .accessibilityIdentifier("carEditor.name")
                }
                Section {
                    TextField("carEditor.odometer.placeholder", text: $odometer)
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("carEditor.odometer")
                } header: {
                    Text("carEditor.odometer.section")
                } footer: {
                    Text("carEditor.odometer.footer")
                }
            }
            .navigationTitle("carEditor.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task {
                            isSaving = true
                            let saved = await onSave(name, odometer)
                            isSaving = false
                            if saved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("carEditor.save")
                }
            }
        }
    }
}
