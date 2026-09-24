import SwiftUI

/// Pit's one question, with normal accessible controls (REQ-PIT-020): answer, "I don't know yet", or "don't ask".
struct PitQuestionCard: View {
    let model: PitQuestionViewModel
    let question: PitAskedQuestion

    @Environment(\.carAvatar) private var carAvatar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            switch question {
            case let .currentMileage(lastKnownKm):
                heading {
                    Text("pit.question.mileage.title")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("pit.question.mileage.reason")
                        .font(.subheadline)
                        .foregroundStyle(PitColor.contentSecondary)
                }
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
            // Side by side at equal widths while both labels fit on one line; stacked otherwise, so neither label
            // wraps or is truncated.
            ViewThatFits(in: .horizontal) {
                PitEqualWidthRow { declineButtons }
                VStack(spacing: 10) { declineButtons }
            }
            .pitSecondaryAction(size: .regular)
            .disabled(isWorking)
        }
        .onChange(of: model.answerText) {
            model.dismissFailure()
        }
    }

    /// The question's words beside the 44 pt avatar of the car the answer belongs to (REQ-BOARD-034); at
    /// accessibility sizes the words move under it, so they keep the card's full width.
    @ViewBuilder
    private func heading(@ViewBuilder _ words: () -> some View) -> some View {
        if let carAvatar {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.tileSpacing))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                CarAvatar(source: carAvatar, size: .pit)
                VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                    words()
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            words()
        }
    }

    /// "I don't know yet" defers: the mileage stays unknown (core C2) and the question is not repeated
    /// (REQ-PIT-012). "Don't ask" dismisses and starts the dismissal cooldown (REQ-PIT-010).
    @ViewBuilder
    private var declineButtons: some View {
        Button {
            Task { await model.deferAnswer() }
        } label: {
            PitActionLabel(title: "pit.question.notKnown", compact: true)
        }
        .accessibilityIdentifier("pit.question.notKnown")
        Button {
            Task { await model.dismiss() }
        } label: {
            PitActionLabel(title: "pit.question.dismiss", compact: true)
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

#if DEBUG
    #Preview("Pit question card") {
        // The card draws only what it is given; the model's stores are never reached in a preview.
        if let registry = try? PitQuestionRegistry.product() {
            PreviewMatrix {
                PitSheetCard {
                    PitQuestionCard(
                        model: PitQuestionViewModel(
                            questions: UnavailablePitQuestionStore(),
                            store: UnavailableCarMemoryStore(),
                            registry: registry
                        ),
                        question: .currentMileage(lastKnownKm: 42500)
                    )
                }
                // The root sets the car; here a fictional sedan with no photo.
                .environment(\.carAvatar, CarAvatarSource(body: .sedan, photo: nil))
            }
        }
    }
#endif
