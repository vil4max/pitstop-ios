import PhotosUI
import SwiftUI

/// What the editor holds until Save. Nothing is stored, lifted or deleted before the owner saves, and an
/// untouched field means unchanged.
struct CarEditorDraft: Equatable {
    var name: String
    var odometer: String
    var body: CarBody
    private(set) var photo: CarPhotoEdit = .unchanged
    /// The last pick could not be loaded; the Photo row says so until the next pick or a remove.
    private(set) var photoLoadFailed = false
    /// The car as the editor opened over it; Save compares the draft with this, so a field left alone stays
    /// unchanged even when Pit recorded a newer value while the editor was open (REQ-PIT-026).
    let opening: CarEditorOpening

    init(opening: CarEditorOpening) {
        let car = opening.car
        name = car.isProvisional ? "" : car.name
        odometer = car.odometerKm.map(String.init) ?? ""
        body = opening.body
        self.opening = opening
    }

    /// `nil` unless the owner picked a body other than the one shown, so SUV is never written for them
    /// (REQ-BOARD-030).
    var bodyChange: CarBody? {
        body == opening.body ? nil : body
    }

    var showsRemovePhoto: Bool {
        switch photo {
        case .unchanged: opening.hasPhoto
        case .replace: true
        case .remove: false
        }
    }

    mutating func choosePhoto(_ data: Data) {
        photo = .replace(data)
        photoLoadFailed = false
    }

    /// Removing a pick that was never saved just drops it; a saved photo is removed on save (REQ-BOARD-033).
    mutating func removePhoto() {
        photo = opening.hasPhoto ? .remove : .unchanged
        photoLoadFailed = false
    }

    mutating func beginPhotoLoad() {
        photoLoadFailed = false
    }

    /// Stages the loaded bytes and returns `true`. Without bytes an earlier pick is dropped, so Save can never
    /// store a photo nobody sees, while a staged remove stays: the owner removed the photo and a failed pick
    /// must not bring it back (REQ-BOARD-033). `false` tells the view to clear the picker selection, so the
    /// same item can be picked again.
    mutating func finishPhotoLoad(_ data: Data?) -> Bool {
        guard let data else {
            if case .replace = photo {
                photo = .unchanged
            }
            photoLoadFailed = true
            return false
        }
        choosePhoto(data)
        return true
    }
}

/// One optional sheet, not a setup step: every field may stay empty, and empty means unchanged. The photo
/// comes from the photo library only, which needs no permission prompt (ADR 0040 "Picking").
struct CarEditorView: View {
    /// False without the App Group container, where no photo could be kept.
    let canChoosePhoto: Bool
    let onSave: (CarEditorDraft) async -> Bool

    @State private var draft: CarEditorDraft
    @State private var pickedItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    /// Only the first `opening` counts: the board reloads under the sheet, and the draft keeps the car it opened
    /// over.
    init(
        opening: CarEditorOpening,
        canChoosePhoto: Bool,
        onSave: @escaping (CarEditorDraft) async -> Bool
    ) {
        self.canChoosePhoto = canChoosePhoto
        self.onSave = onSave
        _draft = State(initialValue: CarEditorDraft(opening: opening))
    }

    var body: some View {
        SaveSheetScaffold(
            title: "carEditor.title",
            saveIdentifier: "carEditor.save",
            // A pick still loading would otherwise be dropped from the save.
            canSave: !isLoadingPhoto,
            // Leaving mid-save would store a photo the owner cancelled, delete the old one's files, and leave
            // the failure alert behind (ADR 0032).
            locksWhileSaving: true
        ) {
            Form {
                if canChoosePhoto {
                    Section("carEditor.photo.section") {
                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("carEditor.photo.choose")
                                    .foregroundStyle(PitColor.contentPrimary)
                                Text("carEditor.photo.footer")
                                    .font(.footnote)
                                    .foregroundStyle(PitColor.contentSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("carEditor.photo.choose")
                        if draft.photoLoadFailed {
                            Text("carEditor.photo.loadFailed")
                                .font(.footnote)
                                .foregroundStyle(PitColor.statusDanger)
                                .accessibilityIdentifier("carEditor.photo.loadFailed")
                        }
                        if draft.showsRemovePhoto {
                            Button("carEditor.photo.remove", role: .destructive) {
                                pickedItem = nil
                                draft.removePhoto()
                            }
                            .accessibilityIdentifier("carEditor.photo.remove")
                        }
                    }
                }
                Section("carEditor.name.section") {
                    TextField("carEditor.name.placeholder", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .pitReportsEditing()
                        .accessibilityIdentifier("carEditor.name")
                }
                Section {
                    Picker("carEditor.body.section", selection: $draft.body) {
                        Text("carEditor.body.suv").tag(CarBody.suv)
                        Text("carEditor.body.sedan").tag(CarBody.sedan)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("carEditor.body")
                } header: {
                    Text("carEditor.body.section")
                } footer: {
                    Text("carEditor.body.footer")
                }
                Section {
                    TextField("carEditor.odometer.placeholder", text: $draft.odometer)
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("carEditor.odometer")
                } header: {
                    Text("carEditor.odometer.section")
                } footer: {
                    Text("carEditor.odometer.footer")
                }
            }
            .task(id: pickedItem) { await loadPickedPhoto() }
        } save: { await onSave(draft) }
    }

    /// Only the bytes are read here; decoding, bounding and the lift wait for Save and run off the main
    /// actor.
    private func loadPickedPhoto() async {
        guard let item = pickedItem else {
            isLoadingPhoto = false
            return
        }
        isLoadingPhoto = true
        draft.beginPhotoLoad()
        // A thrown error and no data are the same to the owner: the photo could not be loaded.
        let data = try? await item.loadTransferable(type: Data.self)
        // A newer pick or a remove replaced this one while it loaded, and that task owns the state now.
        guard !Task.isCancelled else { return }
        if !draft.finishPhotoLoad(data) {
            // With the selection kept, picking the same item again would not start a new load.
            pickedItem = nil
        }
        isLoadingPhoto = false
    }
}

#if DEBUG
    private let previewKestrel = CarEditorOpening(
        car: ProvisionalCarContext(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"), observedKm: 47560),
        body: .sedan,
        hasPhoto: true,
        isMileageCurrent: true,
        mileageObservedAt: nil
    )

    #Preview("Car editor, saved photo, light") {
        CarEditorView(opening: previewKestrel, canChoosePhoto: true) { _ in false }
            .preferredColorScheme(.light)
    }

    #Preview("Car editor, saved photo, dark") {
        CarEditorView(opening: previewKestrel, canChoosePhoto: true) { _ in false }
            .preferredColorScheme(.dark)
    }

    #Preview("Car editor, first launch, AX-XL") {
        CarEditorView(
            opening: CarEditorOpening(
                car: .firstLaunch, body: .suv, hasPhoto: false, isMileageCurrent: false, mileageObservedAt: nil
            ),
            canChoosePhoto: true
        ) { _ in false }
            .dynamicTypeSize(.accessibility3)
    }
#endif
