import SwiftUI

/// Where the lane's pieces stand, measured from the top of the lane. The road line is one coordinate: the
/// car's wheels rest on it and every sign post stands on it; labels start under it (REQ-ROAD-029).
struct RoadLaneGeometry: Equatable {
    static let basePlateSize: CGFloat = 26
    /// Plates stop growing here: a sign is a marker, and at accessibility sizes the list carries the words.
    static let maxPlateSize: CGFloat = 36
    static let postHeight: CGFloat = 12
    static let carWidth: CGFloat = 56
    static let carColumnWidth: CGFloat = 96
    /// Space between the road line and the first label under it.
    static let labelGap: CGFloat = 8

    let plateSize: CGFloat

    init(plateSize: CGFloat) {
        self.plateSize = min(plateSize, Self.maxPlateSize)
    }

    var carHeight: CGFloat {
        Self.carWidth / CarVisual.aspectRatio
    }

    /// The road line: the foot of every post and the bottom of the car's wheels.
    var roadY: CGFloat {
        max(plateSize + Self.postHeight, carHeight)
    }

    var plateTop: CGFloat {
        roadY - Self.postHeight - plateSize
    }

    var carTop: CGFloat {
        roadY - carHeight
    }
}

/// The car at the left and one roadside sign per slot, evenly spaced in order. The view adds, removes and
/// reorders nothing (REQ-ROAD-004). Spacing is ordinal, not a literal scale (ADR 0008). Decorative for
/// VoiceOver: the summary sentence and the list under the lane say the same in words.
struct RoadLaneView: View {
    let slots: [RoadSlot]
    /// The car at "Now": the same picture as the Car Board stage (ADR 0040 "One component").
    let carBody: CarBody
    let carPhoto: CarPhotoFiles?

    static let carID = "road.car"

    @ScaledMetric(relativeTo: .caption) private var plateSize = RoadLaneGeometry.basePlateSize
    /// Slots widen with the text, and the lane scrolls, so a label wraps instead of clipping.
    @ScaledMetric(relativeTo: .caption) private var slotWidth: CGFloat = 128

    var body: some View {
        let geometry = RoadLaneGeometry(plateSize: plateSize)
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: RoadLaneGeometry.labelGap) {
                CarVisual(body: carBody, photo: carPhoto)
                    .frame(width: RoadLaneGeometry.carWidth, height: geometry.carHeight)
                    .padding(.top, geometry.carTop)
                Text("road.now")
                    .font(PitTypography.captionSmall.weight(.semibold))
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .frame(width: RoadLaneGeometry.carColumnWidth)
            .id(Self.carID)

            ForEach(slots) { slot in
                if let sign = slot.sign {
                    RoadSignView(sign: sign, geometry: geometry)
                        .frame(width: slotWidth)
                        .id(slot.id)
                }
            }
        }
        // Each column is a scroll target, so the Road screen can return the lane to the car.
        .scrollTargetLayout()
        .background(alignment: .top) {
            DashedRoadLine()
                .padding(.top, geometry.roadY - DesignTokens.roadLineWidth / 2)
        }
        .accessibilityHidden(true)
    }
}

/// A roadside information sign: a small rounded plate on a post, outlined in the state colour and carrying
/// the state glyph, then the labels under the road. Never a warning shape, never the danger colour.
private struct RoadSignView: View {
    let sign: RoadSign
    let geometry: RoadLaneGeometry

    private var milestone: RoadMilestone {
        sign.milestone
    }

    var body: some View {
        VStack(spacing: RoadLaneGeometry.labelGap) {
            VStack(spacing: 0) {
                plate
                Rectangle()
                    .fill(PitColor.contentSecondary.opacity(0.55))
                    .frame(width: DesignTokens.roadLineWidth, height: RoadLaneGeometry.postHeight)
            }
            .padding(.top, geometry.plateTop)
            labels
        }
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: geometry.plateSize * 0.27, style: .continuous)
        return StatusGlyphView(glyph: milestone.glyph, size: geometry.plateSize * 0.5)
            .foregroundStyle(milestone.color)
            .frame(width: geometry.plateSize, height: geometry.plateSize)
            .background(PitColor.surfaceSecondary, in: shape)
            .overlay(shape.strokeBorder(milestone.color, lineWidth: 1.5))
    }

    private var labels: some View {
        VStack(spacing: 3) {
            milestone.titleText
                .font(PitTypography.caption.weight(.semibold))
                .foregroundStyle(PitColor.contentPrimary)
                .lineLimit(3)
            milestone.distanceText
                .font(PitTypography.captionSmall)
                .foregroundStyle(PitColor.contentSecondary)
                .lineLimit(3)
            if let estimate = milestone.estimate {
                RoadEstimateLine(range: estimate, font: PitTypography.captionSmall)
                    .lineLimit(3)
            }
            if sign.alsoHere > 0 {
                Text("road.cluster.more \(sign.alsoHere)")
                    .font(PitTypography.captionSmall.weight(.medium))
                    .foregroundStyle(PitColor.accentPrimary)
            }
        }
        .multilineTextAlignment(.center)
        // A label takes the lines it needs rather than truncating inside its slot.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
    }
}

#if DEBUG
    #Preview("Road lane") {
        let now = Date.now
        let road = RoadProjector().project(RoadContext(
            now: now,
            maintenanceStates: [],
            plannedEvents: [
                PlannedVehicleEvent(kind: .insuranceExpiry, date: now.addingTimeInterval(-3 * 86400)),
                PlannedVehicleEvent(kind: .other, date: now.addingTimeInterval(38 * 86400), label: "Winter tyres"),
                PlannedVehicleEvent(kind: .plannedVisit, date: now.addingTimeInterval(45 * 86400)),
                PlannedVehicleEvent(kind: .other, date: now.addingTimeInterval(121 * 86400)),
            ]
        ))
        PreviewMatrix {
            StageSurface {
                ScrollView(.horizontal, showsIndicators: false) {
                    RoadLaneView(slots: road.slots, carBody: .sedan, carPhoto: nil)
                }
                .scrollClipDisabled()
            }
        }
    }
#endif
