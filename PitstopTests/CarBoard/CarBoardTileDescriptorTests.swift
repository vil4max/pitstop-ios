@testable import Pitstop
import Testing

@Suite("Car Board tiles")
struct CarBoardTileDescriptorTests {
    @Test("REQ-BOARD-007: tiles come in the same product-defined order every time")
    func orderIsDeterministic() {
        let kinds = CarBoardTileDescriptor.rows().flatMap(\.self).map(\.kind)
        #expect(kinds == [.road, .notes, .service, .history])
        #expect(CarBoardTileDescriptor.rows(CarBoardTileDescriptor.v1.reversed()) == CarBoardTileDescriptor.rows())
    }

    @Test("REQ-BOARD-008: Road is full; Notes, Service, and History are half; nothing else exists")
    func sizesAreFullAndHalfOnly() {
        let sizes = Dictionary(uniqueKeysWithValues: CarBoardTileDescriptor.v1.map { ($0.kind, $0.size) })
        #expect(sizes == [.road: .full, .notes: .half, .service: .half, .history: .half])
        #expect(Set(CarBoardTileDescriptor.v1.map(\.kind)) == Set(CarBoardTileKind.allCases))
    }

    @Test("REQ-BOARD-007: rows follow the contract composition")
    func rowsMatchComposition() {
        let rows = CarBoardTileDescriptor.rows().map { $0.map(\.kind) }
        #expect(rows == [[.road], [.notes, .service], [.history]])
    }

    @Test("ADR-0009: a half tile before a full tile keeps its own row")
    func halfBeforeFullDoesNotPairAcrossIt() {
        let tiles = [
            CarBoardTileDescriptor(kind: .notes, size: .half, defaultOrder: 0),
            CarBoardTileDescriptor(kind: .road, size: .full, defaultOrder: 1),
            CarBoardTileDescriptor(kind: .service, size: .half, defaultOrder: 2),
        ]
        #expect(CarBoardTileDescriptor.rows(tiles).map { $0.map(\.kind) } == [[.notes], [.road], [.service]])
    }
}
