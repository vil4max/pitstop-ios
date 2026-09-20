import SwiftUI

/// Summary + entrance. Until the owning surfaces exist (CB-004…007) each tile shows its honest
/// sparse state: no placeholder metrics, no fake urgency (REQ-BOARD-014, REQ-BOARD-018).
struct CarBoardTileView: View {
    let descriptor: CarBoardTileDescriptor
    var notes: NotesSummary = .empty
    var history: HistoryTimeline = .empty

    var body: some View {
        TileCard(minHeight: minHeight) {
            VStack(alignment: .leading, spacing: 8) {
                TileTitle(title: title, systemImage: systemImage)
                if descriptor.kind == .road {
                    RoadSparseLine()
                        .frame(height: 34)
                        .padding(.vertical, 2)
                }
                if descriptor.kind == .notes, let latest = notes.latest {
                    // The latest thought in the driver's own words, then how many are waiting.
                    Text(latest.rawText)
                        .font(.headline)
                        .foregroundStyle(PitColor.contentPrimary)
                        .lineLimit(2)
                    Text("tile.notes.count \(notes.activeCount)")
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                } else if descriptor.kind == .history, let latest = history.latest {
                    // The latest thing that actually happened, and when.
                    latest.titleText
                        .font(.headline)
                        .foregroundStyle(PitColor.contentPrimary)
                        .lineLimit(2)
                    latest.recencyText()
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                } else {
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(PitColor.contentPrimary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

    private var headline: LocalizedStringKey {
        switch descriptor.kind {
        case .road: "tile.road.empty.headline"
        case .notes: "tile.notes.empty.headline"
        case .service: "tile.service.empty.headline"
        case .history: "tile.history.empty.headline"
        }
    }

    private var detail: LocalizedStringKey {
        switch descriptor.kind {
        case .road: "tile.road.empty.detail"
        case .notes: "tile.notes.empty.detail"
        case .service: "tile.service.empty.detail"
        case .history: "tile.history.empty.detail"
        }
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
