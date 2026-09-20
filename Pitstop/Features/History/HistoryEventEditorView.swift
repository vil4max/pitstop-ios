import SwiftUI

struct HistoryEventEditorView: View {
    let isNew: Bool
    let onSave: (HistoryEventDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: HistoryEventDraft
    @State private var isSaving = false

    init(draft: HistoryEventDraft, isNew: Bool, onSave: @escaping (HistoryEventDraft) async -> Bool) {
        self.isNew = isNew
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    /// An existing event keeps its kind selectable even when that kind is not offered for new events,
    /// so the picker never holds a selection without a matching row.
    private var selectableKinds: [HistoryEventKind] {
        let kinds = HistoryEventKind.userSelectable
        return kinds.contains(draft.kind) ? kinds : kinds + [draft.kind]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("history.editor.kind", selection: $draft.kind) {
                        ForEach(selectableKinds, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    DatePicker("history.editor.date", selection: $draft.date, in: ...Date(), displayedComponents: .date)
                }
                Section {
                    TextField("carEditor.odometer.placeholder", text: $draft.odometerText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("history.editor.odometer")
                    TextField("history.editor.amount.placeholder", text: $draft.amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("history.editor.amount")
                } header: {
                    Text("history.editor.facts")
                } footer: {
                    Text("history.editor.facts.footer")
                }
                Section("history.editor.note") {
                    TextField("history.editor.note.placeholder", text: $draft.note, axis: .vertical)
                        .lineLimit(2 ... 6)
                        .accessibilityIdentifier("history.editor.note")
                }
            }
            .navigationTitle(isNew ? "history.editor.new" : "history.editor.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task {
                            isSaving = true
                            let saved = await onSave(draft)
                            isSaving = false
                            if saved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("history.editor.save")
                }
            }
        }
    }
}
