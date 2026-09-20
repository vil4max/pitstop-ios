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
                    HStack {
                        Label("notes.load.failed", systemImage: "exclamationmark.arrow.circlepath")
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                        Spacer()
                        Button("carBoard.load.retry") {
                            Task { await viewModel.load() }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                if viewModel.state.visibleNotes.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.state.visibleNotes) { note in
                        NoteRow(note: note) {
                            editor = .existing(note)
                        } onToggleArchive: {
                            Task {
                                _ = await viewModel.setStatus(note.status == .active ? .archived : .active, for: note)
                            }
                        }
                    }
                }
            }
        }
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

            if !viewModel.state.availableContexts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        contextChip(nil)
                        ForEach(viewModel.state.availableContexts, id: \.self) { contextChip($0) }
                    }
                }
            }
        }
    }

    private func contextChip(_ context: NoteContext?) -> some View {
        let isSelected = viewModel.state.contextFilter == context
        return Button {
            viewModel.select(context: context)
        } label: {
            Text(context?.title ?? "notes.context.all")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? PitColor.surfaceSecondary : PitColor.contentPrimary)
                .background(isSelected ? PitColor.accentPrimary : PitColor.surfaceSecondary, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                viewModel.state.scope == .active ? "tile.notes.empty.headline" : "notes.archived.empty",
                systemImage: "note.text"
            )
        } description: {
            if viewModel.state.scope == .active {
                Text("tile.notes.empty.detail")
            }
        } actions: {
            if viewModel.state.scope == .active {
                Button("notes.add") { editor = .new }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
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

private struct NoteRow: View {
    let note: Note
    let onOpen: () -> Void
    let onToggleArchive: () -> Void

    var body: some View {
        TileCard(minHeight: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.rawText)
                    .font(.body)
                    .foregroundStyle(PitColor.contentPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(note.createdAt, format: .relative(presentation: .named))
                    ForEach(note.canonicalContexts.sorted { $0.rawValue < $1.rawValue }, id: \.self) { context in
                        Text(context.title)
                    }
                    Spacer(minLength: 8)
                    // Visible, not only in the context menu: archiving is a main action of this list.
                    Button(
                        note.status == .active ? "notes.archive" : "notes.restore",
                        systemImage: note.status == .active ? "archivebox" : "arrow.uturn.backward",
                        action: onToggleArchive
                    )
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 32)
                    // VoiceOver reaches this through the row's named action instead.
                    .accessibilityHidden(true)
                }
                .font(.footnote)
                .foregroundStyle(PitColor.contentSecondary)
            }
        }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("common.edit", systemImage: "pencil", action: onOpen)
            Button(
                note.status == .active ? "notes.archive" : "notes.restore",
                systemImage: note.status == .active ? "archivebox" : "arrow.uturn.backward",
                action: onToggleArchive
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(note.status == .active ? "notes.archive" : "notes.restore"), onToggleArchive)
    }
}

extension NoteContext {
    var title: LocalizedStringKey {
        switch self {
        case .carWash: "notes.context.carWash"
        case .service: "notes.context.service"
        case .shopping: "notes.context.shopping"
        }
    }
}
