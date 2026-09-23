@testable import Pitstop
import Testing

@Suite("Status glyph vocabulary")
struct StatusGlyphTests {
    private let roadStates: [RoadMilestoneState] = [.upcoming, .approaching, .due, .overdue]
    private let serviceStatuses: [MaintenanceStatus] = [.unknown, .upToDate, .approaching, .due]

    @Test("REQ-DESIGN-001: every Road state has its own glyph shape, so due and past due differ beyond colour")
    func roadStatesHaveDistinctGlyphs() {
        #expect(Set(roadStates.map(\.glyph)).count == roadStates.count)
    }

    @Test("REQ-DESIGN-001: every Service status has its own glyph shape")
    func serviceStatusesHaveDistinctGlyphs() {
        #expect(Set(serviceStatuses.map(\.glyph)).count == serviceStatuses.count)
    }

    @Test("REQ-DESIGN-001: one shape means one state across Road and Service")
    func sharedVocabulary() {
        #expect(RoadMilestoneState.upcoming.glyph == MaintenanceStatus.upToDate.glyph)
        #expect(RoadMilestoneState.approaching.glyph == MaintenanceStatus.approaching.glyph)
        #expect(RoadMilestoneState.due.glyph == MaintenanceStatus.due.glyph)
        #expect(MaintenanceStatus.unknown.glyph == .dashed)
        #expect(RoadMilestoneState.overdue.glyph == .filledRing)
    }
}
