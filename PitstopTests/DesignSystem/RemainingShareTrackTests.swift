@testable import Pitstop
import Testing

@Suite("Remaining share track")
struct RemainingShareTrackTests {
    @Test("Past 100 % the bar is full; the state word carries the overdue meaning")
    func overdueFillsTheBar() {
        #expect(RemainingShareTrack.clamped(1.4) == 1)
        #expect(RemainingShareTrack.clamped(0.25) == 0.25)
    }

    @Test("A negative or non-finite share draws an empty bar instead of a broken one")
    func invalidSharesDrawNothing() {
        #expect(RemainingShareTrack.clamped(-0.2) == 0)
        #expect(RemainingShareTrack.clamped(.nan) == 0)
        #expect(RemainingShareTrack.clamped(.infinity) == 0)
    }
}
