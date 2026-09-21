import SwiftUI

extension View {
    /// Stopping removes the owner's rule, so it names the operation and says what stays (ADR 0031).
    func stopTrackingConfirmation(_ viewModel: ServiceViewModel) -> some View {
        modifier(StopTrackingConfirmation(viewModel: viewModel))
    }
}

extension StopTrackingRequest {
    var message: LocalizedStringKey {
        fallsBackToOtherPolicy ? "service.stopTracking.message.fallback" : "service.stopTracking.message"
    }
}

private struct StopTrackingConfirmation: ViewModifier {
    let viewModel: ServiceViewModel

    /// The request stays readable while the dialog animates out, after the view model has cleared it.
    @State private var presented: StopTrackingRequest?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: request
        ) { request in
            Button("service.stopTracking", role: .destructive) {
                Task { _ = await viewModel.confirmStopTracking(request.operation) }
            }
            .accessibilityIdentifier("service.stopTracking.confirm")
            Button("common.cancel", role: .cancel) { viewModel.cancelStopTracking() }
        } message: { request in
            Text(request.message)
        }
        .onChange(of: viewModel.state.stopTrackingCandidate) { _, candidate in
            if let candidate {
                presented = candidate
            }
        }
    }

    private var request: StopTrackingRequest? {
        viewModel.state.stopTrackingCandidate ?? presented
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.stopTrackingCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelStopTracking()
                }
            }
        )
    }

    private var title: Text {
        guard let request else { return Text("service.stopTracking") }
        return Text("service.stopTracking.title \(request.operation.titleText)")
    }
}
