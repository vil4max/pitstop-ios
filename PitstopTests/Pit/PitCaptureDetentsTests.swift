@testable import Pitstop
import SwiftUI
import Testing

@Suite("Pit capture sheet detents")
struct PitCaptureDetentsTests {
    @Test(
        "REQ-PIT-025: at an accessibility text size the sheet opens at the large detent",
        arguments: DynamicTypeSize.allCases.filter(\.isAccessibilitySize)
    )
    func accessibilitySizesOpenLarge(size: DynamicTypeSize) {
        #expect(PitCaptureDetents.initial(for: size) == .large)
    }

    @Test(
        "REQ-PIT-025: below the accessibility sizes the sheet opens at the medium detent",
        arguments: DynamicTypeSize.allCases.filter { !$0.isAccessibilitySize }
    )
    func standardSizesOpenMedium(size: DynamicTypeSize) {
        #expect(PitCaptureDetents.initial(for: size) == .medium)
    }

    @Test("REQ-PIT-025: both detents stay available at every text size, whichever one the sheet opens at")
    func bothDetentsStayAvailable() {
        #expect(PitCaptureDetents.available == [.medium, .large])
        for size in DynamicTypeSize.allCases {
            #expect(PitCaptureDetents.available.contains(PitCaptureDetents.initial(for: size)))
        }
    }
}
