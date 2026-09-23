@testable import Pitstop
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite("Pit equal-width row")
struct PitEqualWidthRowTests {
    @Test("REQ-GRAMMAR-003: the ideal width is the widest child's ideal width times the count, plus the gaps")
    func idealWidthIsWidestTimesCount() {
        #expect(PitEqualWidthRow.idealWidth(of: [40, 100], spacing: 10) == 210)
        #expect(PitEqualWidthRow.idealWidth(of: [60, 30, 45], spacing: 8) == 196)
        #expect(PitEqualWidthRow.idealWidth(of: [], spacing: 10) == 0)
    }

    @Test("REQ-GRAMMAR-003: children get equal shares of the row after the gaps")
    func sharesAreEqual() {
        #expect(PitEqualWidthRow.share(of: 330, count: 2, spacing: 10) == 160)
        #expect(PitEqualWidthRow.share(of: 316, count: 3, spacing: 8) == 100)
    }

    @Test("REQ-GRAMMAR-003: a missing or infinite proposal falls back to the ideal width; a finite one is kept")
    func proposalGuards() {
        #expect(PitEqualWidthRow.width(proposed: nil, idealWidths: [40, 100], spacing: 10) == 210)
        #expect(PitEqualWidthRow.width(proposed: .infinity, idealWidths: [40, 100], spacing: 10) == 210)
        #expect(PitEqualWidthRow.width(proposed: 300, idealWidths: [40, 100], spacing: 10) == 300)
        #expect(PitEqualWidthRow.width(proposed: -5, idealWidths: [40, 100], spacing: 10) == 0)
    }

    @Test("REQ-GRAMMAR-003: a row narrower than its gaps gives each child a zero share, never a negative one")
    func sharesNeverGoNegative() {
        #expect(PitEqualWidthRow.share(of: 0, count: 2, spacing: 10) == 0)
        #expect(PitEqualWidthRow.share(of: 6, count: 3, spacing: 10) == 0)
        #expect(PitEqualWidthRow.share(of: 100, count: 0, spacing: 10) == 0)
    }

    @Test("REQ-GRAMMAR-003: laid out at its ideal size, the row reports the widest child times the count plus gaps")
    func hostedRowReportsItsIdealWidth() {
        let row = PitEqualWidthRow(spacing: 10) {
            Color.clear.frame(width: 40, height: 10)
            Color.clear.frame(width: 100, height: 20)
        }
        .fixedSize()
        let size = UIHostingController(rootView: row).sizeThatFits(in: CGSize(width: 1000, height: 1000))

        #expect(size == CGSize(width: 210, height: 20))
    }
}
