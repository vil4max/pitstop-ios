#if DEBUG
    import SwiftUI

    #Preview("Status glyphs") {
        PreviewMatrix {
            HStack(spacing: 16) {
                ForEach(StatusGlyph.allCases, id: \.self) { glyph in
                    StatusGlyphView(glyph: glyph, size: 18)
                }
            }
            .foregroundStyle(PitColor.statusDue)
        }
    }

    #Preview("Status chips") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 8) {
                StatusChip(Text(verbatim: "Ahead"), glyph: .ring, color: PitColor.accentPrimary)
                StatusChip(Text(verbatim: "Up to date"), glyph: .ring, color: PitColor.statusUpToDate)
                StatusChip(Text(verbatim: "Approaching"), glyph: .half, color: PitColor.statusApproaching)
                StatusChip(Text(verbatim: "Due"), glyph: .filled, color: PitColor.statusDue)
                StatusChip(Text(verbatim: "Past due"), glyph: .filledRing, color: PitColor.statusDue)
                StatusChip(Text(verbatim: "Not enough facts"), glyph: .dashed, color: PitColor.contentSecondary)
            }
        }
    }
#endif
