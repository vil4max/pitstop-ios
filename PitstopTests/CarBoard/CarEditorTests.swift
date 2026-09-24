import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

private let kestrel = ProvisionalCarContext(
    vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"),
    observedKm: 47560
)

@MainActor
@Suite("Car editor")
struct CarEditorTests {

    // MARK: First launch

    @Test("REQ-BOARD-032: a first-launch editor asks for no photo, shows the SUV and saves nothing untouched")
    func firstLaunchEditorAsksForNothing() async {
        let draft = CarEditorDraft(car: .firstLaunch, body: .suv, hasPhoto: false)

        #expect(draft.body == .suv)
        #expect(draft.photo == .unchanged)
        #expect(!draft.showsRemovePhoto)
        #expect(draft.bodyChange == nil)
        #expect(draft.name.isEmpty, "the placeholder name is not offered back as the owner's")

        let store = FakeCarMemoryStore()
        let board = CarBoardViewModel(store: store, now: { now })
        await board.load()
        #expect(board.state.carBody == .suv)
        #expect(board.state.carPhoto == nil)
        #expect(
            await board.saveCar(
                name: draft.name, odometerText: draft.odometer, body: draft.bodyChange, photo: draft.photo
            )
        )
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-BOARD-032: Car Board opens the editor only when the owner asks, and the photo entry is the library")
    func editorOpensOnlyOnRequest() throws {
        let board = try PitInSheetTests.source("Pitstop/Features/CarBoard/CarBoardView.swift")
        #expect(board.contains("@State private var isEditingCar = false"))
        let editor = try PitInSheetTests.source("Pitstop/Features/CarBoard/CarEditorView.swift")
        #expect(editor.contains("PhotosPicker("))
        for camera in ["UIImagePickerController", ".camera", "AVCapture"] {
            #expect(!editor.contains(camera), "the car editor offers a camera entry (\(camera))")
        }
    }

    // MARK: Body

    @Test("REQ-BOARD-030: the editor shows the car's body and sends a change only when the owner makes one")
    func bodyChangeIsTheOwners() {
        var draft = CarEditorDraft(car: kestrel, body: .sedan, hasPhoto: false)
        #expect(draft.body == .sedan)
        #expect(draft.bodyChange == nil)

        draft.body = .suv
        #expect(draft.bodyChange == .suv)

        draft.body = .sedan
        #expect(draft.bodyChange == nil, "choosing the shown body again is no change")
    }

    @Test("REQ-BOARD-030: the Body control offers exactly SUV and Sedan")
    func bodyControlOffersTwoBodies() throws {
        let editor = try PitInSheetTests.source("Pitstop/Features/CarBoard/CarEditorView.swift")
        #expect(CarBody.allCases == [.suv, .sedan])
        #expect(editor.contains("\"carEditor.body.suv\""))
        #expect(editor.contains("\"carEditor.body.sedan\""))
        #expect(editor.contains(".pickerStyle(.segmented)"))
    }

    // MARK: Photo

    @Test("REQ-BOARD-033: removing the photo is offered only while there is one, and saves as a remove")
    func removeIsOfferedWithAPhoto() {
        var draft = CarEditorDraft(car: kestrel, body: .suv, hasPhoto: true)
        #expect(draft.showsRemovePhoto)

        draft.removePhoto()
        #expect(draft.photo == .remove)
        #expect(!draft.showsRemovePhoto)

        let picked = Data([0xFF, 0xD8])
        draft.choosePhoto(picked)
        #expect(draft.photo == .replace(picked))
        #expect(draft.showsRemovePhoto)
    }

    @Test("REQ-BOARD-033: removing a photo picked in this sheet, with none saved, changes nothing")
    func removingAnUnsavedPickChangesNothing() {
        var draft = CarEditorDraft(car: kestrel, body: .suv, hasPhoto: false)
        draft.choosePhoto(Data([0xFF, 0xD8]))
        #expect(draft.showsRemovePhoto)

        draft.removePhoto()
        #expect(draft.photo == .unchanged)
        #expect(!draft.showsRemovePhoto)
    }

    @Test("REQ-BOARD-029: without the App Group container the editor offers no photo")
    func photoNeedsTheContainer() {
        let directory = URL.temporaryDirectory.appending(path: "pitstop-editor-\(UUID().uuidString)")
        let without = CarBoardViewModel(store: FakeCarMemoryStore(), now: { now })
        let with = CarBoardViewModel(
            store: FakeCarMemoryStore(), photos: CarPhotoStore(directory: directory), now: { now }
        )

        #expect(!without.state.canStorePhoto)
        #expect(with.state.canStorePhoto)
    }

    // MARK: Layout and words

    @Test("REQ-BOARD-029: the editor is Photo, Name, Body, then Mileage, as the mockup draws it")
    func sectionsFollowTheMockup() throws {
        let editor = try PitInSheetTests.source("Pitstop/Features/CarBoard/CarEditorView.swift")
        let order = [
            "carEditor.photo.section", "carEditor.name.section", "carEditor.body.section", "carEditor.odometer.section",
        ]
        let positions = try order.map { key in
            try #require(editor.range(of: "\"\(key)\"")?.lowerBound, "\(key) is not in the editor")
        }
        #expect(positions == positions.sorted(), "the sections are not in the mockup's order")
    }

    @Test("REQ-BOARD-029: the editor's new words exist in English, Russian and Ukrainian, in the mockup's English")
    func editorWordsAreLocalized() throws {
        let catalog = try PitInSheetTests.source("Pitstop/Resources/Localizations/Localizable.xcstrings")
        let root = try #require(JSONSerialization.jsonObject(with: Data(catalog.utf8)) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let english = [
            "carEditor.photo.section": "Photo",
            "carEditor.photo.choose": "Choose photo",
            "carEditor.photo.remove": "Remove photo",
            "carEditor.photo.footer": "Stays on this iPhone. Not shared, not in usage data.",
            "carEditor.body.section": "Body",
            "carEditor.body.suv": "SUV",
            "carEditor.body.sedan": "Sedan",
            "carEditor.body.footer": "Shown when there is no photo. Your choice; PitStop never guesses it.",
            "carEditor.failure.profileOnly": "Some changes were saved, but the photo or body was not. Try again.",
        ]
        for (key, value) in english {
            let entry = try #require(strings[key] as? [String: Any], "\(key) is missing")
            let localizations = try #require(entry["localizations"] as? [String: [String: [String: String]]])
            #expect(Set(localizations.keys) == ["en", "ru", "uk"], "\(key) is not in en, ru and uk")
            #expect(localizations["en"]?["stringUnit"]?["value"] == value)
            for language in ["ru", "uk"] {
                let translated = try #require(localizations[language]?["stringUnit"]?["value"])
                #expect(!translated.isEmpty && translated != value, "\(key) is not translated to \(language)")
            }
        }
    }
}
