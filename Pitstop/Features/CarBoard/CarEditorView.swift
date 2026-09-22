import SwiftUI

/// One optional sheet, not a setup step: every field may stay empty, and empty means unchanged.
struct CarEditorView: View {
    let car: ProvisionalCarContext
    let onSave: (_ name: String, _ odometer: String) async -> Bool

    @State private var name: String
    @State private var odometer: String

    init(car: ProvisionalCarContext, onSave: @escaping (_ name: String, _ odometer: String) async -> Bool) {
        self.car = car
        self.onSave = onSave
        _name = State(initialValue: car.isProvisional ? "" : car.name)
        _odometer = State(initialValue: car.odometerKm.map(String.init) ?? "")
    }

    var body: some View {
        SaveSheetScaffold(
            title: "carEditor.title",
            saveIdentifier: "carEditor.save"
        ) {
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
        } save: { await onSave(name, odometer) }
    }
}
