import SwiftUI

/// The share of the owner's own interval that is used up, not a health score (ADR 0038). Past 100 % the bar
/// is full and the state word carries the overdue meaning. VoiceOver reads the fact line instead.
struct RemainingShareTrack: View {
    /// Used share of the interval; clamped to 0...1 when drawn.
    let usedShare: Double
    let color: Color

    var body: some View {
        Capsule()
            .fill(PitColor.surfaceElevated)
            .overlay { UsedPart(share: Self.clamped(usedShare)).fill(color) }
            .frame(height: DesignTokens.shareTrackHeight)
            .clipShape(.capsule)
            .accessibilityHidden(true)
    }

    /// Pure arithmetic, so callers off the main actor (Service's draw rule, tests) can use it.
    nonisolated static func clamped(_ share: Double) -> Double {
        guard share.isFinite else { return 0 }
        return min(max(share, 0), 1)
    }

    /// The leading part of the track, sized from the track's own width rather than the container's.
    private struct UsedPart: Shape {
        let share: Double

        func path(in rect: CGRect) -> Path {
            let used = CGRect(x: rect.minX, y: rect.minY, width: rect.width * share, height: rect.height)
            return Path(roundedRect: used, cornerRadius: rect.height / 2)
        }
    }
}

#if DEBUG
    #Preview("Remaining share") {
        PreviewMatrix {
            VStack(spacing: 12) {
                RemainingShareTrack(usedShare: 0.3, color: PitColor.statusUpToDate)
                RemainingShareTrack(usedShare: 0.85, color: PitColor.statusApproaching)
                RemainingShareTrack(usedShare: 1.4, color: PitColor.statusDue)
            }
        }
    }
#endif
