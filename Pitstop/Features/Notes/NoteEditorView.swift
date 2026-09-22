import SwiftUI

/// Write a new thought or correct a saved one. The sheet closes only after the text was persisted;
/// on failure the text stays in the field for another try (REQ-CAPTURE-009).
struct NoteEditorView: View {
    let target: NoteEditorTarget
    let onSave: (String) async -> Bool

    @State private var text: String
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
        SaveSheetScaffold(
            title: target == .new ? "notes.editor.new" : "notes.editor.edit",
            saveIdentifier: "notes.editor.save",
            canSave: !text.allSatisfy(\.isWhitespace)
        ) {
            TextEditor(text: $text)
                .focused($isFocused)
                .pitActivity(.editing, while: isFocused)
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
                .onAppear { isFocused = true }
        } save: { await onSave(text) }
    }
}
