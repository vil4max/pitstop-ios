import Testing
@testable import Pitstop

@Suite("Greenfield")
struct GreenfieldTests {
    @Test func provisionalCarContext_defaults() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(context.name == ProvisionalCarContext.defaultName)
        #expect(context.odometerKm == 0)
        #expect(context.make == nil)
    }
}
