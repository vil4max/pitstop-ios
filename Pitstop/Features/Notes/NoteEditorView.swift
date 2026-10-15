import SwiftUI

/// Write a new thought or correct a saved one. The sheet closes only after the text was persisted;
/// on failure the text stays in the field for another try (REQ-CAPTURE-009).
struct NoteEditorView: View {
    let target: EditorTarget<Note>
    let onSave: (String) async -> Bool

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(target: EditorTarget<Note>, onSave: @escaping (String) async -> Bool) {
        self.target = target
        self.onSave = onSave
        _text = State(initialValue: target.item?.rawText ?? "")
    }

    var body: some View {
        SaveSheetScaffold(
            title: target == .new ? "notes.editor.new" : "notes.editor.edit",
            saveIdentifier: "notes.editor.save",
            canSave: !text.allSatisfy(\.isWhitespace),
            locksWhileSaving: true
        ) {
            TextEditor(text: $text)
                // "notes.editor.edit" reads "Note": the field's name whether the note is new or saved.
                .accessibilityLabel(Text("notes.editor.edit"))
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
        } save: {
            await onSave(text)
        }
    }
}
