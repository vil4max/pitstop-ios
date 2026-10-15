@testable import Pitstop
import Testing

@Suite("Editor target")
struct EditorTargetTests {
    @Test("A new item's sheet and a saved item's sheet have ids of their own")
    func sheetIdentity() {
        let note = DomainFixtures.Notes.rawThought
        let other = DomainFixtures.Notes.archivedNote
        #expect(EditorTarget<Note>.new.id == "new")
        #expect(EditorTarget<Note>.new.item == nil)
        #expect(EditorTarget.existing(note).id == note.id.uuidString)
        #expect(EditorTarget.existing(note).item == note)
        #expect(EditorTarget.existing(note).id != EditorTarget.existing(other).id)
    }
}
