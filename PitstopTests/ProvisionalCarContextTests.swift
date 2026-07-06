import Testing
@testable import Pitstop

@Suite("ProvisionalCarContext")
struct ProvisionalCarContextTests {
    @Test func defaults() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(context.name == ProvisionalCarContext.defaultName)
        #expect(context.odometerKm == 0)
        #expect(context.make == nil)
    }
}
