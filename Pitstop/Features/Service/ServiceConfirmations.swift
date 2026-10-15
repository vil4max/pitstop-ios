import SwiftUI

extension View {
    /// Stopping removes the owner's rule, so it names the operation and says what stays (ADR 0031).
    func stopTrackingConfirmation(_ viewModel: ServiceViewModel) -> some View {
        latchedConfirmation(candidate: viewModel.state.stopTrackingCandidate) { request in
            guard let request else { return Text("service.stopTracking") }
            return Text("service.stopTracking.title \(request.operation.titleText)")
        } cancel: {
            viewModel.cancelStopTracking()
        } actions: { request in
            Button("service.stopTracking", role: .destructive) {
                Task { _ = await viewModel.confirmStopTracking(request.operation) }
            }
            .accessibilityIdentifier("service.stopTracking.confirm")
            Button("common.cancel", role: .cancel) { viewModel.cancelStopTracking() }
        } message: { request in
            Text(request.message)
        }
    }

    /// Deleting the car's reading names the operation and says what stays (ADR 0035, the ADR 0031 pattern).
    func deleteReportConfirmation(_ viewModel: ServiceViewModel) -> some View {
        latchedConfirmation(candidate: viewModel.state.deleteReportCandidate) { operation in
            guard let operation else { return Text("service.report.delete") }
            return Text("service.report.delete.title \(operation.titleText)")
        } cancel: {
            viewModel.cancelDeleteReport()
        } actions: { operation in
            Button("service.report.delete", role: .destructive) {
                Task { _ = await viewModel.confirmDeleteReport(operation) }
            }
            .accessibilityIdentifier("service.report.delete.confirm")
            Button("common.cancel", role: .cancel) { viewModel.cancelDeleteReport() }
        } message: { _ in
            Text("service.report.delete.message")
        }
    }
}

extension StopTrackingRequest {
    var message: LocalizedStringKey {
        fallsBackToOtherPolicy ? "service.stopTracking.message.fallback" : "service.stopTracking.message"
    }
}
