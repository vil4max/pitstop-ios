import SwiftUI

/// Pit's capture surface: write, let PitStop read it or save it as written, then confirm, answer one
/// question, or see where it went. It is never a chat history (pit-behavior-and-motion.md, "Capture").
struct PitCaptureView: View {
    let viewModel: PitCaptureViewModel
    /// Pit's pending question, shown above the composer; it never replaces capture (ADR 0017).
    let question: PitQuestionViewModel
    let visible: VisibleFeature?
    let onOpen: (PitDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var eyes = PitCaptureEyes()
    @FocusState private var isFocused: Bool
    @State private var answerText = ""
    @State private var isScrolling = false

    var body: some View {
        @Bindable var model = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                    HStack(spacing: 12) {
                        PitEyesGlyph(state: eyes.state, life: eyes.life).scaleEffect(1.6)
                            .frame(width: 44, height: 36)
                        Text("pit.title").font(.title2.bold())
                    }
                    content(model: $model.text, mode: $model.mode)
                }
                .padding(DesignTokens.screenPadding)
            }
            .onScrollPhaseChange { _, phase in isScrolling = phase != .idle }
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
        .presentationDetents([.medium, .large])
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
        .onDisappear { eyes.stop() }
    }

    @ViewBuilder
    private func content(model text: Binding<String>, mode: Binding<RememberMode>) -> some View {
        switch viewModel.phase {
        case .composing:
            // Remember stays the primary surface (REQ-PIT-013). A pending question sits above it and can be
            // answered or declined here, but the user may write a note without touching it (ADR 0017).
            switch question.phase {
            case let .asking(asked), let .working(asked):
                TileCard(minHeight: 0) {
                    PitQuestionCard(model: question, question: asked)
                }
                composer(text: text, mode: mode)
            case let .answered(kilometers):
                Label("pit.question.answered \(kilometers)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(PitColor.statusUpToDate)
                composer(text: text, mode: mode)
            case .silent:
                composer(text: text, mode: mode)
            }
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

    private func composer(text: Binding<String>, mode: Binding<RememberMode>) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            TextField("pit.placeholder", text: text, axis: .vertical)
                .lineLimit(3 ... 8)
                .focused($isFocused)
                .padding(DesignTokens.tilePadding)
                .background(PitColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("pit.text")
            Picker("pit.title", selection: mode) {
                Text("pit.mode.interpreted").tag(RememberMode.interpreted)
                Text("pit.mode.raw").tag(RememberMode.raw)
            }
            .pickerStyle(.segmented)
            Text("pit.mode.footer")
                .font(.footnote)
                .foregroundStyle(PitColor.contentSecondary)
            Button {
                Task { await viewModel.submit(from: visible) }
            } label: {
                Text("pit.save").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSubmit)
            .accessibilityIdentifier("pit.save")
        }
        // With a question pending the keyboard would cover it; the user chooses where to type.
        .onAppear { isFocused = !question.isAsking }
    }

    private func confirmation(_ pending: PendingCapture) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            Text("pit.confirm.title").font(.headline)
            TileCard(minHeight: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: pending.rawText)
                        .font(.body)
                        .foregroundStyle(PitColor.contentSecondary)
                    summary(pending.content)
                        .font(.headline)
                    ForEach(Array(pending.conflicts.enumerated()), id: \.offset) { _, conflict in
                        conflictText(conflict)
                            .font(.footnote)
                            .foregroundStyle(PitColor.statusDue)
                    }
                    // Every fact that will be written is shown before it is confirmed.
                    ForEach(Array(facts(pending.content).enumerated()), id: \.offset) { _, fact in
                        fact.font(.subheadline)
                    }
                    if let cycleNote = pending.content.cycleNote {
                        Text(cycleNote)
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                    }
                }
            }
            Button {
                Task { await viewModel.confirm() }
            } label: {
                Text("pit.confirm.save").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("pit.confirm")
            Button {
                Task { await viewModel.keepWordsOnly() }
            } label: {
                Text("pit.confirm.asNote").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func clarification(_ request: ClarificationRequest) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            Text(verbatim: request.rawText)
                .foregroundStyle(PitColor.contentSecondary)
            Text(question(request.question, kind: request.kind)).font(.headline)
            switch request.question {
            case .odometerKm, .amount:
                TextField("pit.clarify.answer", text: $answerText)
                    .keyboardType(request.question == .amount ? .decimalPad : .numberPad)
                    .padding(DesignTokens.tilePadding)
                    .background(PitColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button {
                    Task { await viewModel.answer(text: answerText) }
                } label: {
                    Text("pit.clarify.answer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(answerText.isBlank)
            case .operationID:
                ForEach(MaintenanceOperationID.catalog, id: \.self) { operation in
                    choice(operation.titleText) { await viewModel.answer(.operation(operation)) }
                }
            case .eventKind:
                ForEach(HistoryEventKind.userSelectable, id: \.self) { kind in
                    choice(Text(kind.title)) { await viewModel.answer(.eventKind(kind)) }
                }
            case .vehicleFact, .policyInterval, .remainingValue:
                // Not answerable in a single step here; the wording can always be kept.
                EmptyView()
            }
            // "I don't know" is always offered: unknown is a valid answer (core C2).
            Button {
                Task { await viewModel.answer(.unknown) }
            } label: {
                Text("pit.clarify.unknown").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func saved(_ destination: PitDestination, preservedRaw: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            Label(preservedRaw ? "pit.saved.note" : "pit.saved.interpreted", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(PitColor.statusUpToDate)
            // Where it went, in words, even when there is no screen to open (REQ-CAPTURE-010).
            Text(destinationName(destination))
                .font(.subheadline)
                .foregroundStyle(PitColor.contentSecondary)
            if let link = link(for: destination) {
                Button {
                    dismiss()
                    onOpen(destination)
                } label: {
                    Text(link).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button {
                viewModel.reset()
            } label: {
                Text("pit.saved.another").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func choice(_ label: Text, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            label.frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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
