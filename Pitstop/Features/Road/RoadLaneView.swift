import SwiftUI

/// The car at the left and the slots the projection returned, evenly spaced in order. The view adds,
/// removes, and reorders nothing (REQ-ROAD-004). Spacing is ordinal, not a literal scale (ADR 0008).
struct RoadLaneView: View {
    let slots: [RoadSlot]
    var isCompact = false
    /// On the Road screen each child is a scroll target; the modifier must sit on the stack itself.
    var isScrollTarget = false

    static let carID = "road.car"

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 6) {
                AbstractCarView()
                    .frame(width: isCompact ? 54 : 72)
                Text("road.now")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .frame(width: isCompact ? 70 : 96)
            .id(Self.carID)

            ForEach(slots) { slot in
                RoadSlotView(slot: slot, isCompact: isCompact)
                    .id(slot.id)
            }
        }
        .modifier(ScrollTargets(isEnabled: isScrollTarget))
        .background(alignment: .top) {
            // The road itself: one dashed line behind the markers.
            Rectangle()
                .fill(.clear)
                .frame(height: 2)
                .overlay {
                    Line()
                        .stroke(
                            PitColor.contentTertiary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8])
                        )
                }
                .padding(.top, isCompact ? 22 : 30)
                .accessibilityHidden(true)
        }
    }
}

private struct ScrollTargets: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct RoadSlotView: View {
    let slot: RoadSlot
    let isCompact: Bool

    var body: some View {
        if let lead = slot.lead {
            VStack(spacing: 6) {
                Image(systemName: lead.state.systemImage)
                    .font(isCompact ? .body : .title3)
                    .foregroundStyle(lead.state.color)
                    .padding(4)
                    .background(PitColor.surfaceSecondary, in: .circle)
                    .padding(.top, isCompact ? 8 : 14)
                lead.titleText
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PitColor.contentPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                lead.distanceText
                    .font(.caption2)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(PitColor.contentSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if slot.milestones.count > 1 {
                    // A cluster shows one label and a count, so labels can never overlap (REQ-ROAD-013).
                    Text("road.cluster.more \(slot.milestones.count - 1)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PitColor.accentPrimary)
                }
            }
            // In a tile the slots share the width that is left; on the Road screen they keep a readable
            // fixed width and the lane scrolls.
            .frame(minWidth: isCompact ? 0 : 128, maxWidth: isCompact ? .infinity : 128)
            .accessibilityElement(children: .combine)
        }
    }
}
