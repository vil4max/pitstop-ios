import SwiftUI

/// Write a new thought or correct a saved one. The sheet closes only after the text was persisted;
/// on failure the text stays in the field for another try (REQ-CAPTURE-009).
struct NoteEditorView: View {
    let target: NoteEditorTarget
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    init(target: NoteEditorTarget, onSave: @escaping (String) async -> Bool) {
        self.target = target
        self.onSave = onSave
        if case let .existing(note) = target {
            _text = State(initialValue: note.rawText)
        } else {
            _text = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                .padding(.horizontal, DesignTokens.screenPadding - 4)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("notes.editor.placeholder")
                            .foregroundStyle(PitColor.contentTertiary)
                            .padding(.horizontal, DesignTokens.screenPadding)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("notes.editor.text")
                .navigationTitle(target == .new ? "notes.editor.new" : "notes.editor.edit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.save") {
                            Task {
                                isSaving = true
                                let saved = await onSave(text)
                                isSaving = false
                                if saved {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(isSaving || text.allSatisfy(\.isWhitespace))
                        .accessibilityIdentifier("notes.editor.save")
                    }
                }
                .onAppear { isFocused = true }
        }
    }
}
