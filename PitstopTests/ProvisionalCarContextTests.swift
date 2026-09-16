@testable import Pitstop
import Testing

@Suite("ProvisionalCarContext")
struct ProvisionalCarContextTests {
    @Test("REQ-DOMAIN-002: first launch has a display name and no vehicle facts")
    func firstLaunchHasNoVehicleFacts() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(context.name == ProvisionalCarContext.defaultName)
        #expect(context.odometerKm == nil)
        #expect(context.make == nil)
        #expect(context.model == nil)
        #expect(context.year == nil)
    }

    @Test("REQ-BOARD-004: unknown mileage is never shown as 0 km")
    func unknownMileageIsNotZero() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(CarBoardMileage(odometerKm: context.odometerKm) == .unknown)
    }

    @Test("REQ-BOARD-005: a supplied zero reading is shown as 0 km")
    func suppliedZeroReadingIsShown() {
        #expect(CarBoardMileage(odometerKm: 0) == .kilometers(0))
    }
}
