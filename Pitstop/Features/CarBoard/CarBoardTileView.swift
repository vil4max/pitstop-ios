import SwiftUI

/// Summary + entrance in the shared anatomy (REQ-BOARD-028): title row with a chevron, primary line, a status
/// chip only where a state exists, secondary line. `CarBoardTileContent` decides what each line says; there
/// are no placeholder metrics and no fake urgency (REQ-BOARD-014, REQ-BOARD-018).
struct CarBoardTileView: View {
    let descriptor: CarBoardTileDescriptor
    var notes: NotesSummary = .empty
    var history: HistoryTimeline = .empty
    var service: [MaintenanceOperationState] = []
    var road: RoadProjection?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var content: CarBoardTileContent {
        CarBoardTileContent(kind: descriptor.kind, notes: notes, history: history, service: service, road: road)
    }

    var body: some View {
        let content = content
        TileCard(minHeight: minHeight) {
            VStack(alignment: .leading, spacing: 8) {
                titleRow
                if descriptor.kind == .road {
                    if content.roadSlots.isEmpty {
                        RoadSparseLine()
                            .frame(height: 34)
                            .padding(.vertical, 2)
                    } else {
                        // At accessibility sizes the labels cannot fit side by side: the markers stay, the
                        // sentence below carries the words, and no label is clipped. The drawing itself stops
                        // growing at the largest standard size so the plates never outgrow the car.
                        CarBoardRoadLane(slots: content.roadSlots, showsLabels: !dynamicTypeSize.isAccessibilitySize)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    primaryText(content.primary)
                    if let status = content.status {
                        StatusChip(Text(status.statusLabel), glyph: status.status.glyph, color: status.status.color)
                    }
                    text(for: content.secondary)
                        .font(PitTypography.supportingSmall)
                        .foregroundStyle(PitColor.contentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            TileTitle(title: title, systemImage: systemImage)
            Spacer(minLength: 4)
            // "Entrance" made visible; the link itself is the button VoiceOver announces.
            Image(systemName: "chevron.right")
                .font(PitTypography.supportingSmall.weight(.semibold))
                .foregroundStyle(PitColor.contentTertiary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func primaryText(_ line: CarBoardTileContent.Line) -> some View {
        switch line {
        case .roadSummary:
            // A sentence, not a title: it wraps in full because it is Road's whole meaning without the drawing.
            text(for: line)
                .font(PitTypography.supporting.weight(.medium))
                .foregroundStyle(PitColor.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)
        default:
            text(for: line)
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.contentPrimary)
                // A preview of the owner's words; at accessibility sizes it gets room to keep its meaning.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 2)
        }
    }

    private func text(for line: CarBoardTileContent.Line) -> Text {
        switch line {
        case let .sparseHeadline(kind): Text(Self.sparseHeadline(kind))
        case let .sparseDetail(kind): Text(Self.sparseDetail(kind))
        case let .roadSummary(road): road.summaryText
        case let .roadHorizon(horizon): Text(Self.horizonKey(horizon))
        case let .noteText(text): Text(verbatim: text)
        case let .activeNotes(count): Text("tile.notes.count \(count)")
        case let .serviceTitle(operation): operation.titleText
        case let .serviceProgress(state): state.progressText
        case let .historyTitle(entry): entry.titleText
        case let .historyRecency(date): FeatureFormat.dayRecency(of: date)
        }
    }

    private static func horizonKey(_ horizon: RoadHorizon) -> LocalizedStringKey {
        switch horizon {
        case .standard: "road.tile.horizon"
        case .extendedToNearest: "road.tile.nothingSoon"
        case .waitingForMileage: "road.waiting.title"
        case .noKnownMilestones: "tile.road.empty.detail"
        }
    }

    private var minHeight: CGFloat {
        descriptor.size == .full ? DesignTokens.fullTileMinHeight : DesignTokens.halfTileMinHeight
    }

    private var title: LocalizedStringKey {
        switch descriptor.kind {
        case .road: "tile.road.title"
        case .notes: "tile.notes.title"
        case .service: "tile.service.title"
        case .history: "tile.history.title"
        }
    }

    private var systemImage: String {
        switch descriptor.kind {
        case .road: "road.lanes"
        case .notes: "note.text"
        case .service: "wrench.and.screwdriver"
        case .history: "clock.arrow.circlepath"
        }
    }

    private static func sparseHeadline(_ kind: CarBoardTileKind) -> LocalizedStringKey {
        switch kind {
        case .road: "tile.road.empty.headline"
        case .notes: "tile.notes.empty.headline"
        case .service: "tile.service.empty.headline"
        case .history: "tile.history.empty.headline"
        }
    }

    private static func sparseDetail(_ kind: CarBoardTileKind) -> LocalizedStringKey {
        switch kind {
        case .road: "tile.road.empty.detail"
        case .notes: "tile.notes.empty.detail"
        case .service: "tile.service.empty.detail"
        case .history: "tile.history.empty.detail"
        }
    }
}

/// The car at "Now" and the projection's initial slots as roadside markers with the shared state glyphs
/// (REQ-DESIGN-001). The tile adds, removes and reorders nothing (REQ-ROAD-004); decorative for VoiceOver,
/// because the summary sentence under it says the same in words (REQ-BOARD-023).
private struct CarBoardRoadLane: View {
    let slots: [RoadSlot]
    let showsLabels: Bool
    @ScaledMetric(relativeTo: .caption) private var plateSize: CGFloat = 22

    private static let postHeight: CGFloat = 9
    private static let carWidth: CGFloat = 54

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 6) {
                AbstractCarView()
                    .frame(width: Self.carWidth)
                    // The wheels stand on the road, level with the foot of every post.
                    .padding(.top, max(0, roadY - Self.carWidth / 2.6))
                Text("road.now")
                    .font(PitTypography.captionSmall.weight(.semibold))
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .frame(width: 70)
            ForEach(slots) { slot in
                if let lead = slot.lead {
                    marker(lead, clusterSize: slot.milestones.count)
                }
            }
        }
        .background(alignment: .top) {
            RoadLine()
                .stroke(PitColor.contentTertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8]))
                .frame(height: 2)
                .padding(.top, roadY - 1)
        }
        .accessibilityHidden(true)
    }

    /// The road line: under the car's wheels and at the foot of every marker's post.
    private var roadY: CGFloat {
        plateSize + Self.postHeight
    }

    private func marker(_ milestone: RoadMilestone, clusterSize: Int) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: 0) {
                StatusGlyphView(glyph: milestone.glyph, size: plateSize * 0.46)
                    .foregroundStyle(milestone.state.color)
                    .frame(width: plateSize, height: plateSize)
                    .background(PitColor.surfaceSecondary, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(milestone.state.color, lineWidth: 1.5))
                Rectangle()
                    .fill(PitColor.contentSecondary.opacity(0.55))
                    .frame(width: 2, height: Self.postHeight)
            }
            if showsLabels {
                milestone.titleText
                    .font(PitTypography.caption.weight(.semibold))
                    .foregroundStyle(PitColor.contentPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                milestone.distanceText
                    .font(PitTypography.captionSmall)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(PitColor.contentSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if clusterSize > 1 {
                    // A cluster shows one label and a count, so labels never overlap (REQ-ROAD-013).
                    Text("road.cluster.more \(clusterSize - 1)")
                        .font(PitTypography.captionSmall.weight(.medium))
                        .foregroundStyle(PitColor.accentPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RoadLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// The car at the left of an open road with no milestones drawn: nothing is invented.
private struct RoadSparseLine: View {
    var body: some View {
        GeometryReader { proxy in
            let roadY = proxy.size.height * 0.72
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: roadY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: roadY))
                }
                .stroke(PitColor.contentTertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8]))
                AbstractCarView()
                    .frame(width: 58)
                    .offset(y: roadY - 24)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Car Board tiles") {
        PreviewMatrix {
            VStack(spacing: DesignTokens.tileSpacing) {
                CarBoardTileView(descriptor: CarBoardTileDescriptor.v1[0])
                CarBoardTileView(
                    descriptor: CarBoardTileDescriptor.v1[1],
                    notes: NotesSummary(notes: [Note(rawText: "Left wiper streaks at speed")])
                )
                CarBoardTileView(descriptor: CarBoardTileDescriptor.v1[2])
            }
        }
    }
#endif
