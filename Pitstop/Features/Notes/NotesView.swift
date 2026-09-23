import SwiftUI

struct NotesView: View {
    let viewModel: NotesViewModel
    let carName: String

    @State private var editor: NoteEditorTarget?

    var body: some View {
        FeatureScaffold(carName: carName, title: String(localized: "tile.notes.title")) {
            VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                controls
                if viewModel.state.isLoadFailed {
                    LoadFailureBanner(message: "notes.load.failed") { await viewModel.load() }
                }
                if viewModel.state.visibleNotes.isEmpty {
                    emptyState
                } else {
                    NoteList(notes: viewModel.state.visibleNotes) { note in
                        editor = .existing(note)
                    } onToggleArchive: { note in
                        Task { _ = await viewModel.setStatus(NoteArchiveToggle(note).targetStatus, for: note) }
                    }
                }
            }
        }
        // Rows in a scroll view, not a `List`: this keeps one row's swipe open at a time and closes it on scroll.
        .swipeActionsContainer()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("notes.add", systemImage: "square.and.pencil") { editor = .new }
                    .accessibilityIdentifier("notes.add")
            }
        }
        .task { await viewModel.prepareForDisplay() }
        .alert("notes.failure.status", isPresented: listFailureBinding) {
            Button("common.ok") { viewModel.dismissFailure() }
        }
        .pitActivity(.modalTask, while: editor != nil || listFailureBinding.wrappedValue)
        .sheet(item: $editor) { target in
            NoteEditorView(target: target) { text in
                switch target {
                case .new: await viewModel.add(text: text)
                case let .existing(note): await viewModel.correct(note, text: text)
                }
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("notes.scope", selection: scopeBinding) {
                Text("notes.scope.active").tag(NoteStatus.active)
                Text("notes.scope.archived").tag(NoteStatus.archived)
            }
            .pickerStyle(.segmented)

            NoteContextChips(chips: viewModel.state.contextChips, selection: viewModel.state.contextFilter) {
                viewModel.select(context: $0)
            }
        }
    }

    private var emptyState: some View {
        FeatureEmptyState(
            title: viewModel.state.scope == .active ? "tile.notes.empty.headline" : "notes.archived.empty",
            systemImage: "note.text"
        ) {
            if viewModel.state.scope == .active {
                Text("tile.notes.empty.detail")
            }
        } actions: {
            if viewModel.state.scope == .active {
                Button("notes.add") { editor = .new }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var scopeBinding: Binding<NoteStatus> {
        Binding(get: { viewModel.state.scope }, set: { viewModel.select(scope: $0) })
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.editorFailure != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFailure()
                }
            }
        )
    }

    private var listFailureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.listFailure != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFailure()
                }
            }
        )
    }

    private var failureTitle: LocalizedStringKey {
        switch viewModel.state.editorFailure {
        case .emptyText: "notes.failure.empty"
        case .notSaved, .none: "notes.failure.notSaved"
        }
    }
}

enum NoteEditorTarget: Identifiable, Equatable {
    case new
    case existing(Note)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(note): note.id.uuidString
        }
    }
}

/// The context filter as chips that wrap at every size, so each label stays whole at accessibility sizes instead
/// of scrolling off screen (REQ-GRAMMAR-003). "All" leads and is the main list (REQ-BOARD-012).
private struct NoteContextChips: View {
    let chips: [NoteContext?]
    let selection: NoteContext?
    let onSelect: (NoteContext?) -> Void

    var body: some View {
        if !chips.isEmpty {
            ChipFlowLayout(spacing: 8, lineSpacing: 4) {
                ForEach(chips, id: \.self) { context in
                    let isSelected = selection == context
                    Button {
                        onSelect(context)
                    } label: {
                        Text(context?.title ?? "notes.context.all")
                    }
                    .buttonStyle(NoteContextChipStyle(isSelected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A filter chip on the surface fill with a hairline; the selected one fills with the accent (mockup #notes).
private struct NoteContextChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PitTypography.supporting.weight(.medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isSelected ? PitColor.contentOnAccent : PitColor.contentPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? PitColor.accentPrimary : PitColor.surfaceSecondary, in: .capsule)
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(PitColor.separator, lineWidth: DesignTokens.hairline)
                }
            }
            .opacity(configuration.isPressed ? 0.6 : 1)
            // The chip looks about 36 pt tall; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}

/// The notes of the current scope and filter as rows of one grouped list (REQ-GRAMMAR-001).
private struct NoteList: View {
    let notes: [Note]
    let onOpen: (Note) -> Void
    let onToggleArchive: (Note) -> Void

    var body: some View {
        GroupedSection {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                NoteRow(note: note, showsSeparator: index > 0) {
                    onOpen(note)
                } onToggleArchive: {
                    onToggleArchive(note)
                }
            }
        }
    }
}

/// The driver's words in body weight and a meta line with recency and context. Archiving is a main action of this
/// list, so it is a visible glyph, a trailing swipe and a VoiceOver action, all calling `onToggleArchive`.
private struct NoteRow: View {
    let note: Note
    var showsSeparator = false
    let onOpen: () -> Void
    let onToggleArchive: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var toggle: NoteArchiveToggle {
        NoteArchiveToggle(note)
    }

    var body: some View {
        // At accessibility sizes the glyph moves under the text on the trailing edge, so the text keeps the width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        layout {
            Button(action: onOpen) {
                // The row's padding is inside the button, so a tap anywhere on the row but the glyph opens the note.
                details
                    .padding(.top, 12)
                    .padding(.bottom, isAccessibilitySize ? 0 : 12)
                    .padding(.leading, DesignTokens.groupedRowPadding)
                    .padding(.trailing, isAccessibilitySize ? DesignTokens.groupedRowPadding : 0)
            }
            .buttonStyle(.plain)
            .accessibilityAction(named: Text(toggle.title), onToggleArchive)
            archiveButton
                .padding(.top, isAccessibilitySize ? 0 : 2)
                .padding(.bottom, isAccessibilitySize ? 4 : 0)
                .padding(.trailing, DesignTokens.groupedRowPadding - 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .swipeActions(edge: .trailing) {
            Button(toggle.title, systemImage: toggle.systemImage, action: onToggleArchive)
                .tint(PitColor.accentPrimary)
        }
        .contextMenu {
            Button("common.edit", systemImage: "pencil", action: onOpen)
            Button(toggle.title, systemImage: toggle.systemImage, action: onToggleArchive)
        }
        // Outside the swipe, so the hairline stays put while the row slides.
        .groupedRowSeparator(showsSeparator)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.rawText)
                .font(PitTypography.body)
                .foregroundStyle(PitColor.contentPrimary)
            note.metaText
                .font(PitTypography.supportingSmall)
                .foregroundStyle(PitColor.contentSecondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var archiveButton: some View {
        Button(action: onToggleArchive) {
            // The 44 pt frame is inside the label, so the whole box is the tap target, not only the drawn glyph.
            Image(systemName: toggle.systemImage)
                .font(PitTypography.body)
                .foregroundStyle(PitColor.accentPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // VoiceOver reaches this through the row's named action instead.
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Notes chips and rows") {
        let now = Date.now
        let notes = [
            Note(
                rawText: "Ask about the stain on the rear seat",
                createdAt: now.addingTimeInterval(-2 * 3600),
                canonicalContexts: [.carWash]
            ),
            Note(
                rawText: "Left rear tyre loses a little air each week, check at the next visit",
                createdAt: now.addingTimeInterval(-3 * 86400),
                canonicalContexts: [.service]
            ),
            Note(
                rawText: "Rattle from the glovebox over cobbles, only when cold",
                createdAt: now.addingTimeInterval(-14 * 86400)
            ),
        ]
        PreviewMatrix {
            VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                NoteContextChips(chips: [nil, .carWash, .service, .shopping], selection: nil) { _ in }
                NoteList(notes: notes) { _ in } onToggleArchive: { _ in }
            }
        }
    }
#endif
