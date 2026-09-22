import SwiftUI

/// What the owner typed into the dashboard sheet, as text: the view model parses and checks it.
struct DashboardReadingEntry: Equatable {
    var distance = ""
    var unit: DistanceUnit
    var days = ""
    var odometer = ""
}

/// The owner copies what the car's display says is left (ADR 0035). The unit is always visible and
/// chosen explicitly, because a reading in miles entered as kilometres moves the anchor by 60%.
struct DashboardReadingView: View {
    let operation: MaintenanceOperationID
    let defaultUnit: DistanceUnit
    let odometerPrefill: Int?
    let onSave: (DashboardReadingEntry) async -> Bool

    @State private var entry: DashboardReadingEntry?

    var body: some View {
        SaveSheetScaffold(
            title: "service.report.sheet.title",
            saveIdentifier: "service.report.save",
            canSave: entry != nil
        ) {
            Form {
                Section {
                    TextField("service.report.sheet.distance", text: binding(\.distance))
                        .keyboardType(.numbersAndPunctuation)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.report.distance")
                    Picker("service.report.sheet.unit", selection: binding(\.unit)) {
                        Text(DistanceUnit.kilometers.title).tag(DistanceUnit.kilometers)
                        Text(DistanceUnit.miles.title).tag(DistanceUnit.miles)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("service.report.unit")
                    TextField("service.report.sheet.days", text: binding(\.days))
                        .keyboardType(.numbersAndPunctuation)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.report.days")
                } header: {
                    operation.titleText
                } footer: {
                    Text("service.report.sheet.footer")
                }
                Section {
                    TextField("service.report.sheet.odometer", text: binding(\.odometer))
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.report.odometer")
                } footer: {
                    Text("service.report.sheet.odometerFooter")
                }
            }
            .onAppear {
                guard entry == nil else { return }
                entry = DashboardReadingEntry(unit: defaultUnit, odometer: odometerPrefill.map(String.init) ?? "")
            }
        } save: {
            guard let entry else { return false }
            return await onSave(entry)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<DashboardReadingEntry, Value>) -> Binding<Value> {
        Binding(
            get: { (entry ?? DashboardReadingEntry(unit: defaultUnit))[keyPath: keyPath] },
            set: { value in
                var updated = entry ?? DashboardReadingEntry(unit: defaultUnit)
                updated[keyPath: keyPath] = value
                entry = updated
            }
        )
    }
}

extension View {
    /// Deleting the car's reading names the operation and says what stays (ADR 0035, the ADR 0031
    /// pattern).
    func deleteReportConfirmation(_ viewModel: ServiceViewModel) -> some View {
        modifier(DeleteReportConfirmation(viewModel: viewModel))
    }
}

private struct DeleteReportConfirmation: ViewModifier {
    let viewModel: ServiceViewModel

    /// The operation stays readable while the dialog animates out, after the view model has cleared it.
    @State private var presented: MaintenanceOperationID?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: operation
        ) { operation in
            Button("service.report.delete", role: .destructive) {
                Task { _ = await viewModel.confirmDeleteReport(operation) }
            }
            .accessibilityIdentifier("service.report.delete.confirm")
            Button("common.cancel", role: .cancel) { viewModel.cancelDeleteReport() }
        } message: { _ in
            Text("service.report.delete.message")
        }
        .onChange(of: viewModel.state.deleteReportCandidate) { _, candidate in
            if let candidate {
                presented = candidate
            }
        }
    }

    private var operation: MaintenanceOperationID? {
        viewModel.state.deleteReportCandidate ?? presented
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.deleteReportCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelDeleteReport()
                }
            }
        )
    }

    private var title: Text {
        guard let operation else { return Text("service.report.delete") }
        return Text("service.report.delete.title \(operation.titleText)")
    }
}
