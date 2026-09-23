import SwiftUI

/// Pit's one question, with normal accessible controls (REQ-PIT-020): answer, "I don't know yet", or "don't ask".
struct PitQuestionCard: View {
    let model: PitQuestionViewModel
    let question: PitAskedQuestion

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            switch question {
            case let .currentMileage(lastKnownKm):
                Text("pit.question.mileage.title")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("pit.question.mileage.reason")
                    .font(.subheadline)
                    .foregroundStyle(PitColor.contentSecondary)
                if let lastKnownKm {
                    // The last observation is shown as history, never as today's mileage (core C2).
                    Text("pit.question.mileage.last \(lastKnownKm)")
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                }
                TextField("pit.question.mileage.field", text: $model.answerText)
                    .keyboardType(.numberPad)
                    .padding(DesignTokens.tilePadding)
                    // The card sits on a secondary surface, so the field uses the primary one to stay visible.
                    .background(PitColor.surfacePrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier("pit.question.answer")
            }
            if let failure = model.failure {
                Text(failureText(failure))
                    .font(.footnote)
                    .foregroundStyle(PitColor.statusDue)
            }
            Button {
                Task { await model.answer() }
            } label: {
                PitActionLabel(title: "pit.question.save", prominent: true)
            }
            .pitPrimaryAction()
            .disabled(model.answerText.isBlank || isWorking)
            .accessibilityIdentifier("pit.question.save")
            // Side by side while they fit; stacked at large text sizes, so neither label is truncated.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignTokens.tileSpacing) { declineButtons }
                VStack(spacing: DesignTokens.tileSpacing) { declineButtons }
            }
            .pitSecondaryAction()
            .disabled(isWorking)
        }
        .onChange(of: model.answerText) {
            model.dismissFailure()
        }
    }

    /// "I don't know yet" defers: the mileage stays unknown (core C2) and the question is not repeated
    /// (REQ-PIT-012). "Don't ask" dismisses and starts the dismissal cooldown (REQ-PIT-010).
    @ViewBuilder
    private var declineButtons: some View {
        Button {
            Task { await model.deferAnswer() }
        } label: {
            PitActionLabel(title: "pit.question.notKnown")
        }
        .accessibilityIdentifier("pit.question.notKnown")
        Button {
            Task { await model.dismiss() }
        } label: {
            PitActionLabel(title: "pit.question.dismiss")
        }
        .accessibilityIdentifier("pit.question.dismiss")
    }

    private var isWorking: Bool {
        if case .working = model.phase {
            true
        } else {
            false
        }
    }

    private func failureText(_ failure: PitQuestionFailure) -> LocalizedStringKey {
        switch failure {
        case .invalidMileage: "carEditor.failure.odometer"
        case .notSaved: "pit.failure.notSaved"
        }
    }
}
