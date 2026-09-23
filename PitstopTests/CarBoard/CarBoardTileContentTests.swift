import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

private func content(
    _ kind: CarBoardTileKind,
    notes: NotesSummary = .empty,
    history: HistoryTimeline = .empty,
    service: [MaintenanceOperationState] = [],
    road: RoadProjection? = nil
) -> CarBoardTileContent {
    CarBoardTileContent(kind: kind, notes: notes, history: history, service: service, road: road)
}

private func project(
    _ states: [MaintenanceOperationState],
    day: Double,
    planned: [PlannedVehicleEvent] = []
) -> RoadProjection {
    RoadProjector().project(RoadContext(now: Fix.date(day), maintenanceStates: states, plannedEvents: planned))
}

@Suite("Car Board tile anatomy")
struct CarBoardTileContentTests {
    @Test("REQ-BOARD-028: with no facts every tile still has a primary and a secondary line, and no chip")
    func sparseTiles() {
        for kind in CarBoardTileKind.allCases {
            let tile = content(kind, road: kind == .road ? project([], day: 0) : nil)
            #expect(tile.primary == .sparseHeadline(kind))
            #expect(tile.secondary == .sparseDetail(kind))
            #expect(tile.status == nil, "no state exists, so no chip (REQ-BOARD-014)")
            #expect(tile.roadSlots.isEmpty)
        }
    }

    @Test("REQ-BOARD-028: Service shows its most urgent operation with a status chip")
    func serviceHasChip() throws {
        let states = Fix.states([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: 59000, day: 10)
        let subject = try #require(states.byUrgency.summarySubject)

        let tile = content(.service, service: states.byUrgency)

        #expect(tile.primary == .serviceTitle(.engineOilService))
        #expect(tile.status == subject)
        #expect(tile.secondary == .serviceProgress(subject))
    }

    @Test("REQ-BOARD-028: Notes and History carry no chip; they have no state")
    func notesAndHistoryHaveNoChip() {
        let note = Note(rawText: "Left wiper streaks at speed", createdAt: Fix.date(1))
        let notes = NotesSummary(notes: [note])
        let wash = HistoryEvent(vehicleID: Fix.vehicleID, kind: .carWash, date: Fix.date(2))
        let history = HistoryTimeline(events: [wash], completions: [])

        let notesTile = content(.notes, notes: notes)
        let historyTile = content(.history, history: history)

        #expect(notesTile.primary == .noteText("Left wiper streaks at speed"))
        #expect(notesTile.secondary == .activeNotes(1))
        #expect(notesTile.status == nil)
        #expect(historyTile.primary == .historyTitle(.event(wash)))
        #expect(historyTile.secondary == .historyRecency(Fix.date(2)))
        #expect(historyTile.status == nil)
    }

    @Test("REQ-BOARD-028: Road draws the projection's initial slots as state markers; the sentence stays the meaning")
    func roadMarkers() {
        // Oil approaching (1 200 km left of 10 000) and an insurance date well ahead.
        let states = Fix.states([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: 58800, day: 10)
        let insurance = PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(80))
        let road = project(states, day: 10, planned: [insurance])

        let tile = content(.road, road: road)

        #expect(tile.roadSlots == Array(road.initialSlots))
        #expect(tile.roadSlots.count == 2)
        #expect(Set(tile.roadSlots.compactMap(\.lead?.glyph)) == [.half, .ring])
        #expect(tile.primary == .roadSummary(road))
        #expect(tile.secondary == .roadHorizon(.standard))
        #expect(tile.status == nil, "the state word is part of the Road sentence")
    }

    @Test("REQ-BOARD-028: a Road waiting for mileage places no marker and says what it waits for")
    func roadWaitingForMileage() {
        let states = Fix.states([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: nil, day: 200)
        let road = project(states, day: 200)

        let tile = content(.road, road: road)

        #expect(road.horizon == .waitingForMileage)
        #expect(tile.roadSlots.isEmpty)
        #expect(tile.primary == .roadSummary(road))
        #expect(tile.secondary == .roadHorizon(.waitingForMileage))
    }

    @Test("REQ-BOARD-028: tracked operations without a baseline leave Road empty and say why")
    func roadWithoutBaseline() {
        let states = Fix.states([Fix.oil10k], [], currentKm: 50000, day: 10)
        let road = project(states, day: 10)

        let tile = content(.road, road: road)

        #expect(tile.primary == .sparseHeadline(.road))
        #expect(tile.secondary == .roadSummary(road))
        #expect(tile.roadSlots.isEmpty)
    }
}
