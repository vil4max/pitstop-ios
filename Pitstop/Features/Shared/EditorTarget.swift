import Foundation

/// What an editor sheet opens on: a new item, or one already saved. The sheet's id is "new" or the saved item's
/// id, so the open sheet keeps its identity and another item opens a sheet of its own.
enum EditorTarget<Item: Identifiable & Equatable>: Identifiable, Equatable where Item.ID == UUID {
    case new
    case existing(Item)

    var id: String {
        item?.id.uuidString ?? "new"
    }

    var item: Item? {
        if case let .existing(item) = self {
            item
        } else {
            nil
        }
    }
}
