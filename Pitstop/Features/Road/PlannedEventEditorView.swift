import SwiftUI

/// Where a planned date is added or corrected (ADR 0032). It asks for a kind, a day, and for `other`
/// an optional short name, and for nothing else: no insurer, policy number, or amount.
struct PlannedEventEditorView: View {
    let isNew: Bool
    let kinds: [PlannedEventDraft.Kind]
    let dateRange: ClosedRange<Date>
    let onSave: (PlannedEventDraft) async -> Bool

    @State private var draft: PlannedEventDraft

    init(
        draft: PlannedEventDraft,
        isNew: Bool,
        kinds: [PlannedEventDraft.Kind],
        dateRange: ClosedRange<Date>,
        onSave: @escaping (PlannedEventDraft) async -> Bool
    ) {
        self.isNew = isNew
        self.kinds = kinds
        self.dateRange = dateRange
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        // Leaving mid-save would store a date the owner cancelled, or leave its failure behind.
        SaveSheetScaffold(
            title: isNew ? "road.addDate" : "road.planned.editor.edit",
            saveIdentifier: "road.planned.editor.save",
            locksWhileSaving: true
        ) {
            Form {
                Section {
                    Picker("road.planned.editor.kind", selection: $draft.kind) {
                        ForEach(kinds, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .accessibilityIdentifier("road.planned.editor.kind")
                    DatePicker(
                        "road.planned.editor.date",
                        selection: $draft.date,
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("road.planned.editor.date")
                } footer: {
                    Text("road.planned.editor.footer")
                }
                if draft.kind == .other {
                    Section {
                        TextField("road.planned.editor.label.placeholder", text: $draft.label)
                            .pitReportsEditing()
                            .accessibilityIdentifier("road.planned.editor.label")
                            .onChange(of: draft.label) { _, label in
                                // The limit is enforced while typing, so saving never loses what was typed.
                                if label.count > PlannedEventLimits.maximumLabelLength {
                                    draft.label = String(label.prefix(PlannedEventLimits.maximumLabelLength))
                                }
                            }
                    } header: {
                        Text("road.planned.editor.label")
                    } footer: {
                        Text("road.planned.editor.label.footer \(PlannedEventLimits.maximumLabelLength)")
                    }
                }
            }
        } save: { await onSave(draft) }
    }
}

extension View {
    /// Deleting removes the owner's stated date, so it names the date first (ADR 0032).
    func plannedEventDeleteConfirmation(_ viewModel: RoadViewModel) -> some View {
        modifier(PlannedEventDeleteConfirmation(viewModel: viewModel))
    }
}

private struct PlannedEventDeleteConfirmation: ViewModifier {
    let viewModel: RoadViewModel

    /// The event stays readable while the dialog animates out, after the view model has cleared it.
    @State private var presented: PlannedDatedEvent?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: event
        ) { event in
            Button("road.planned.delete", role: .destructive) {
                Task { _ = await viewModel.confirmDelete(event) }
            }
            .accessibilityIdentifier("road.planned.delete.confirm")
            Button("common.cancel", role: .cancel) { viewModel.cancelDelete() }
        } message: { event in
            // Two unnamed dates share a title, so the message names the day being deleted.
            Text("road.planned.delete.message \(event.date.formatted(date: .long, time: .omitted))")
        }
        .onChange(of: viewModel.state.deleteCandidate) { _, candidate in
            if let candidate {
                presented = candidate
            }
        }
    }

    private var event: PlannedDatedEvent? {
        viewModel.state.deleteCandidate ?? presented
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.deleteCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelDelete()
                }
            }
        )
    }

    private var title: Text {
        guard let event else { return Text("road.planned.delete") }
        return Text("road.planned.delete.title \(event.titleText)")
    }
}
