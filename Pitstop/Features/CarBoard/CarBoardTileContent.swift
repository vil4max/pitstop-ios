import Foundation

/// What a tile says before it is tapped, in the shared anatomy (REQ-BOARD-028): a title row, a primary line,
/// a status chip only where a state exists, and a secondary line. Deciding it here keeps the view a renderer
/// and the rules testable; each line is a fact, never a placeholder metric (REQ-BOARD-018).
struct CarBoardTileContent: Equatable {
    enum Line: Equatable {
        /// The honest sparse state of a tile with nothing to summarize (REQ-BOARD-011, REQ-BOARD-014).
        case sparseHeadline(CarBoardTileKind)
        case sparseDetail(CarBoardTileKind)
        /// Road's semantic summary sentence, the tile's accessible meaning (REQ-BOARD-023).
        case roadSummary(RoadProjection)
        /// Which stretch of road the markers show (REQ-BOARD-010).
        case roadHorizon(RoadHorizon)
        case noteText(String)
        case activeNotes(Int)
        case serviceTitle(MaintenanceOperationID)
        case serviceProgress(MaintenanceOperationState)
        case historyTitle(HistoryEntry)
        case historyRecency(Date)
    }

    let primary: Line
    /// Service's most urgent operation, whose status becomes the chip. Nil wherever no state exists; Road says
    /// its state inside the summary sentence instead.
    let status: MaintenanceOperationState?
    let secondary: Line
    /// Road only: the projection's initial slots, drawn as markers in order (REQ-ROAD-004).
    let roadSlots: [RoadSlot]

    init(
        kind: CarBoardTileKind,
        notes: NotesSummary,
        history: HistoryTimeline,
        service: [MaintenanceOperationState],
        road: RoadProjection?
    ) {
        var primary = Line.sparseHeadline(kind)
        var secondary = Line.sparseDetail(kind)
        var status: MaintenanceOperationState?
        var roadSlots: [RoadSlot] = []
        switch kind {
        case .road:
            if let road, !road.isCompletelyEmpty {
                if case .noKnownMilestones = road.semanticSummary {
                    // Something is tracked but nothing can be placed: the sentence explains why.
                    secondary = .roadSummary(road)
                } else {
                    primary = .roadSummary(road)
                    secondary = .roadHorizon(road.horizon)
                    roadSlots = Array(road.initialSlots)
                }
            }
        case .notes:
            if let latest = notes.latest {
                // The latest thought in the driver's own words, then how many are waiting.
                primary = .noteText(latest.rawText)
                secondary = .activeNotes(notes.activeCount)
            }
        case .service:
            if let subject = service.summarySubject {
                primary = .serviceTitle(subject.id)
                status = subject
                secondary = .serviceProgress(subject)
            }
        case .history:
            if let latest = history.latest {
                // The latest thing that actually happened, and when.
                primary = .historyTitle(latest)
                secondary = .historyRecency(latest.date)
            }
        }
        self.primary = primary
        self.secondary = secondary
        self.status = status
        self.roadSlots = roadSlots
    }
}
