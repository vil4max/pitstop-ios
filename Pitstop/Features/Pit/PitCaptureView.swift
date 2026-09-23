import SwiftUI

/// Pit's capture surface: write, let PitStop read it or save it as written, then confirm, answer one
/// question, or see where it went. It is never a chat history (pit-behavior-and-motion.md, "Capture").
struct PitCaptureView: View {
    let viewModel: PitCaptureViewModel
    /// Pit's pending question, shown above the composer; it never replaces capture (ADR 0017).
    let question: PitQuestionViewModel
    let visible: VisibleFeature?
    /// Nil over another sheet: opening a screen there would close that sheet and drop its input (REQ-PIT-026).
    let onOpen: ((PitDestination) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var eyes = PitCaptureEyes()
    @FocusState private var isFocused: Bool
    @State private var answerText = ""
    @State private var isScrolling = false
    /// The sheet's detent: fixed from the text size when the sheet opens (REQ-PIT-025), then only the user's drag
    /// changes it; a text-size change while the sheet is open does not move it.
    @State private var chosenDetent: PresentationDetent?

    var body: some View {
        @Bindable var model = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Self.spacing) {
                    PitMomentHeader(title: moment.title, eyes: eyes.state, life: eyes.life)
                    content(model: $model.text, mode: $model.mode)
                }
                .padding(DesignTokens.screenPadding)
            }
            .onScrollPhaseChange { _, phase in isScrolling = phase != .idle }
            // Remember is pinned here, above the keyboard, while the user writes; with Pit's question pending only at
            // accessibility sizes, where the field alone fills the space above the keyboard (REQ-PIT-025). The rule
            // is `PitSheetMoment.rememberAction(at:)`.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let action = moment.rememberAction(at: dynamicTypeSize), action.placement == .pinned {
                    rememberButton(prominent: action.isProminent)
                        .padding(.horizontal, DesignTokens.screenPadding)
                        .padding(.vertical, 12)
                        .background(PitColor.surfacePrimary)
                }
            }
            .background(PitColor.surfacePrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        viewModel.cancel()
                        dismiss()
                    }
                    // A write in flight finishes and shows its result; it is never cancelled halfway.
                    .disabled(viewModel.phase == .working || isQuestionWorking)
                }
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
        .presentationDetents(PitCaptureDetents.available, selection: detent)
        // Neither a save in flight nor unsent words can be swiped away. Close cancels unsent words and
        // pending proposals, and waits for a save in flight.
        .interactiveDismissDisabled(
            viewModel.phase == .working || isQuestionWorking
                || (viewModel.phase == .composing && !viewModel.text.isBlank)
        )
        .onChange(of: viewModel.phase) { answerText = "" }
        // The eyes follow the capture; the beats between moments live in `PitCaptureEyes` (ADR 0028).
        .onChange(of: EyeInput(moment: eyeMoment, reduceMotion: reduceMotion), initial: true) { _, input in
            eyes.update(to: input.moment, reduceMotion: input.reduceMotion)
        }
        .onChange(of: sheetActivity, initial: true) { _, activity in eyes.setActivity(activity) }
        .onAppear {
            if chosenDetent == nil {
                chosenDetent = PitCaptureDetents.initial(for: dynamicTypeSize)
            }
        }
        .onDisappear { eyes.stop() }
    }

    /// The one moment the sheet shows; earlier turns are never drawn (REQ-PIT-021).
    private var moment: PitSheetMoment {
        PitSheetMoment(capture: viewModel.phase, question: question.phase)
    }

    private static let spacing: CGFloat = 16

    @ViewBuilder
    private func content(model text: Binding<String>, mode: Binding<RememberMode>) -> some View {
        switch moment {
        case let .composing(notice):
            // Remember stays the primary surface (REQ-PIT-013). A pending question sits above it and can be
            // answered or declined here, but the user may write a note without touching it (ADR 0017).
            switch notice {
            case let .question(asked):
                PitSheetCard {
                    PitQuestionCard(model: question, question: asked)
                }
            case let .answered(kilometers):
                Label("pit.question.answered \(kilometers)", systemImage: "checkmark.circle.fill")
                    .font(PitTypography.supporting)
                    .foregroundStyle(PitColor.statusUpToDate)
            case .none:
                EmptyView()
            }
            composer(text: text, mode: mode)
        case .working:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case let .confirming(pending):
            confirmation(pending)
        case let .clarifying(request):
            clarification(request)
        case let .saved(destination, preservedRaw):
            saved(destination, preservedRaw: preservedRaw)
        }
    }

    @ViewBuilder
    private func rememberButton(prominent: Bool) -> some View {
        let button = Button {
            Task { await viewModel.submit(from: visible) }
        } label: {
            PitActionLabel(title: "pit.save", prominent: prominent)
        }
        Group {
            if prominent {
                button.pitPrimaryAction()
            } else {
                button.pitSecondaryAction()
            }
        }
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("pit.save")
    }

    private func composer(text: Binding<String>, mode: Binding<RememberMode>) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            TextField("pit.placeholder", text: text, axis: .vertical)
                .lineLimit(3 ... 8)
                .focused($isFocused)
                .padding(DesignTokens.tilePadding)
                .background(PitColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("pit.text")
            VStack(alignment: .leading, spacing: 8) {
                Picker("pit.title", selection: mode) {
                    Text("pit.mode.interpreted").tag(RememberMode.interpreted)
                    Text("pit.mode.raw").tag(RememberMode.raw)
                }
                .pickerStyle(.segmented)
                Text("pit.mode.footer")
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action = moment.rememberAction(at: dynamicTypeSize), action.placement == .inline {
                rememberButton(prominent: action.isProminent)
            }
        }
        // With a question pending the keyboard would cover it; the user chooses where to type. Once the question is
        // answered, deferred or dismissed, the composer takes the focus again, as when it first appears.
        .onAppear { isFocused = !question.isAsking }
        .onChange(of: question.isAsking) { _, isAsking in isFocused = !isAsking }
    }

    private func confirmation(_ pending: PendingCapture) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            PitSheetCard {
                // The user's own words come first, then what PitStop made of them (REQ-CAPTURE-016).
                PitQuotedWords(text: pending.rawText)
                summary(pending.content)
                    .font(PitTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(pending.conflicts.enumerated()), id: \.offset) { _, conflict in
                    conflictText(conflict)
                        .font(PitTypography.supportingSmall)
                        .foregroundStyle(PitColor.statusDue)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Every fact that will be written is shown before it is confirmed.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(facts(pending.content).enumerated()), id: \.offset) { _, fact in
                        fact
                            .font(PitTypography.supporting)
                            .monospacedDigit()
                            .foregroundStyle(PitColor.contentSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let cycleNote = pending.content.cycleNote {
                    Text(cycleNote)
                        .font(PitTypography.supportingSmall)
                        .foregroundStyle(PitColor.contentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                Task { await viewModel.confirm() }
            } label: {
                PitActionLabel(title: "pit.confirm.save", prominent: true)
            }
            .pitPrimaryAction()
            .accessibilityIdentifier("pit.confirm")
            Button {
                Task { await viewModel.keepWordsOnly() }
            } label: {
                PitActionLabel(title: "pit.confirm.asNote")
            }
            .pitSecondaryAction()
        }
    }

    private func clarification(_ request: ClarificationRequest) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            PitQuotedWords(text: request.rawText)
            // The capture's one question (REQ-PIT-003); the header already says "One thing".
            Text(question(request.question, kind: request.kind))
                .font(PitTypography.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            switch request.question {
            case .odometerKm, .amount:
                TextField("pit.clarify.answer", text: $answerText)
                    .keyboardType(request.question == .amount ? .decimalPad : .numberPad)
                    .padding(DesignTokens.tilePadding)
                    .background(PitColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button {
                    Task { await viewModel.answer(text: answerText) }
                } label: {
                    PitActionLabel(title: "pit.clarify.answer", prominent: true)
                }
                .pitPrimaryAction()
                .disabled(answerText.isBlank)
            case .operationID, .eventKind:
                PitChoiceList(choices: choices(for: request.question)) { answer in
                    Task { await viewModel.answer(answer) }
                }
            case .vehicleFact, .policyInterval, .remainingValue:
                // Not answerable in a single step here; the wording can always be kept.
                EmptyView()
            }
            // "I don't know" is always offered: unknown is a valid answer (core C2).
            Button {
                Task { await viewModel.answer(.unknown) }
            } label: {
                PitActionLabel(title: "pit.clarify.unknown")
            }
            .pitSecondaryAction()
        }
    }

    private func saved(_ destination: PitDestination, preservedRaw: Bool) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            VStack(alignment: .leading, spacing: 4) {
                // The header says "Saved."; saving the words as written is still told (REQ-CAPTURE-008).
                if preservedRaw {
                    Text("pit.saved.note")
                        .foregroundStyle(PitColor.contentPrimary)
                }
                // Where it went, in words, even when there is no screen to open (REQ-CAPTURE-010).
                Text(destinationName(destination))
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .font(PitTypography.body)
            .fixedSize(horizontal: false, vertical: true)
            if let onOpen, let link = link(for: destination) {
                Button {
                    dismiss()
                    onOpen(destination)
                } label: {
                    PitActionLabel(title: link)
                }
                .pitSecondaryAction()
            }
            // The one way to continue: a fresh composer in the same sheet, with nothing of this capture left.
            Button {
                viewModel.reset()
            } label: {
                PitActionLabel(title: "pit.saved.another", prominent: true)
            }
            .pitPrimaryAction()
        }
    }

    private func choices(for field: ProposalField) -> [PitChoice] {
        switch field {
        case .operationID:
            MaintenanceOperationID.catalog.map { PitChoice(label: $0.titleText, answer: .operation($0)) }
        case .eventKind:
            HistoryEventKind.userSelectable.map { PitChoice(label: Text($0.title), answer: .eventKind($0)) }
        case .odometerKm, .amount, .vehicleFact, .policyInterval, .remainingValue:
            []
        }
    }

    // MARK: - Words

    private func facts(_ content: ValidatedContent) -> [Text] {
        switch content {
        case let .maintenanceCompletion(_, date, kilometers):
            [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
                + (kilometers.map { [Text("pit.confirm.atMileage \($0)")] } ?? [])
        case let .odometerReading(_, date):
            [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
        case let .vehicleEvent(kind, date, kilometers, amount):
            eventFacts(kind: kind, date: date, kilometers: kilometers, amount: amount)
        case let .expense(kind, date, kilometers, amount):
            eventFacts(kind: kind, date: date, kilometers: kilometers, amount: amount)
        case let .maintenancePolicy(_, distance, months):
            (distance.map { [Text("pit.confirm.everyKm \($0)")] } ?? [])
                + (months.map { [Text("pit.confirm.everyMonths \($0)")] } ?? [])
        case let .vehicleServiceReport(_, date, kilometers, distance, unit, days):
            // The reading exactly as it will be stored, in the unit the car showed (ADR 0035).
            VehicleServiceReport.carSaysTexts(distance: distance, unit: unit, days: days)
                .map { Text("pit.confirm.carSays \($0)") }
                + [Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
                + (kilometers.map { [Text("pit.confirm.atMileage \($0)")] } ?? [])
        case .note, .vehicleFact:
            []
        }
    }

    private func eventFacts(kind: HistoryEventKind, date: Date, kilometers: Int?, amount: Decimal?) -> [Text] {
        var facts = [Text(kind.title), Text("pit.confirm.on \(date.formatted(date: .long, time: .omitted))")]
        if let kilometers {
            facts.append(Text("pit.confirm.atMileage \(kilometers)"))
        }
        if let amount {
            facts.append(Text("pit.confirm.amount \(FeatureFormat.amount(amount))"))
        }
        return facts
    }

    private func destinationName(_ destination: PitDestination) -> LocalizedStringKey {
        switch destination {
        case .notes: "pit.saved.to.notes"
        case .history: "pit.saved.to.history"
        case .service: "pit.saved.to.service"
        case .carBoard: "pit.saved.to.car"
        }
    }

    /// The fallback only serves the first frame, before `onAppear` fixes the detent; it gives the same value.
    private var detent: Binding<PresentationDetent> {
        Binding(
            get: { chosenDetent ?? PitCaptureDetents.initial(for: dynamicTypeSize) },
            set: { chosenDetent = $0 }
        )
    }

    private var isQuestionWorking: Bool {
        if case .working = question.phase {
            true
        } else {
            false
        }
    }

    private func summary(_ content: ValidatedContent) -> Text {
        switch content {
        case let .maintenanceCompletion(operation, _, _): Text("pit.confirm.completion \(operation.titleText)")
        case let .odometerReading(kilometers, _): Text("pit.confirm.reading \(Int(kilometers.rounded()))")
        case .vehicleEvent, .expense: Text("pit.confirm.event")
        case let .vehicleFact(fact): Text("pit.confirm.fact \(fact.field.title) \(fact.value)")
        case let .maintenancePolicy(operation, _, _): Text("pit.confirm.policy \(operation.titleText)")
        case let .vehicleServiceReport(operation, _, _, _, _, _):
            Text("pit.confirm.vehicleReport \(operation.titleText)")
        case .note: Text("pit.confirm.note")
        }
    }

    private func conflictText(_ conflict: ProposalConflict) -> Text {
        switch conflict {
        case let .odometerBelowLatest(latest): Text("pit.confirm.conflict.mileage \(Int(latest.rounded()))")
        case let .replacesVehicleFact(_, existing): Text("pit.confirm.conflict.fact \(existing)")
        }
    }

    private func question(_ field: ProposalField, kind: ProposalKind) -> LocalizedStringKey {
        switch field {
        case .odometerKm: "pit.clarify.odometerKm"
        // The car's reading names no work done; asking "what was done?" would suggest it does.
        case .operationID where kind == .vehicleServiceReport: "pit.clarify.operationID.report"
        case .operationID: "pit.clarify.operationID"
        case .vehicleFact: "pit.clarify.vehicleFact"
        case .policyInterval: "pit.clarify.policyInterval"
        case .eventKind: "pit.clarify.eventKind"
        case .amount: "pit.clarify.amount"
        case .remainingValue: "pit.clarify.remainingValue"
        }
    }

    private func link(for destination: PitDestination) -> LocalizedStringKey? {
        switch destination {
        case .notes: "pit.saved.openNotes"
        case .history: "pit.saved.openHistory"
        case .service: "pit.saved.openService"
        case .carBoard: nil
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.failure != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFailure()
                }
            }
        )
    }

    private var failureTitle: LocalizedStringKey {
        switch viewModel.failure {
        case .alreadySaved: "pit.failure.alreadySaved"
        case .invalidMileage: "carEditor.failure.odometer"
        case .invalidAmount: "history.failure.amount"
        case .notSaved, .none: "pit.failure.notSaved"
        }
    }
}

private extension PitCaptureView {
    struct EyeInput: Equatable {
        let moment: PitCaptureMoment
        let reduceMotion: Bool
    }

    /// Typing in the composer and scrolling the sheet; Pit's eyes hold still for both (REQ-PIT-005).
    var sheetActivity: PitActivity {
        PitActivity().union(isFocused ? .editing : []).union(isScrolling ? .scrolling : [])
    }

    var eyeMoment: PitCaptureMoment {
        PitCaptureMoment(viewModel.phase, isAsking: question.isAsking)
    }
}

private extension VehicleFactField {
    var title: Text {
        switch self {
        case .name: Text("carEditor.name.section")
        case .make: Text("pit.fact.make")
        case .model: Text("pit.fact.model")
        case .year: Text("pit.fact.year")
        case .vin: Text(verbatim: "VIN")
        }
    }
}
