import SwiftUI
import WidgetKit

/// "Next service": the operation Service lists first, as its name, status word and one fact (ADR 0036).
/// It reads the car memory read-only from the App Group container and never writes; a tap opens Service.
struct NextServiceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NextServiceWidgetKind.kind, provider: NextServiceTimelineProvider()) { entry in
            NextServiceWidgetView(content: entry.content)
                .widgetURL(AppLink.service.url)
        }
        .configurationDisplayName("widget.nextService.title")
        .description("widget.nextService.description")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct NextServiceTimelineProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
        let content: NextServiceContent
    }

    /// Fictional: the gallery and the placeholder never show the owner's data.
    static let sample = NextServiceContent.operation(NextServiceSummary(
        operation: .engineOilService,
        status: .approaching,
        word: .approaching,
        fact: .progress(.kilometersAhead(1200), block: nil)
    ))

    func placeholder(in _: Context) -> Entry {
        Entry(date: .now, content: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (Entry) -> Void) {
        if context.isPreview {
            completion(Entry(date: .now, content: Self.sample))
            return
        }
        let now = Date.now
        completion(Entry(date: now, content: Self.plan(now: now).content))
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<Entry>) -> Void) {
        let now = Date.now
        let plan = Self.plan(now: now)
        let policy: TimelineReloadPolicy = plan.refreshDate.map { .after($0) } ?? .never
        completion(Timeline(entries: [Entry(date: now, content: plan.content)], policy: policy))
    }

    private static func plan(now: Date) -> NextServiceTimelinePlan {
        NextServiceTimelinePlan(now: now) {
            try StoreLocation.readableGroupStore().map(NextServiceStoreReader.facts(at:))
        }
    }
}

struct NextServiceWidgetView: View {
    let content: NextServiceContent
    @Environment(\.widgetFamily) private var family
    /// The Lock Screen status glyph grows with the text beside it, as a chip's glyph does.
    @ScaledMetric(relativeTo: .body) private var statusGlyphSize = DesignTokens.lockScreenStatusGlyphSize

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
                .containerBackground(for: .widget) {}
        default:
            small
                .containerBackground(for: .widget) {
                    PitColor.surfaceSecondary
                }
        }
    }

    /// One line of system-rendered text: WidgetKit draws only text and an SF Symbol here, so the status glyph and
    /// the design roles cannot apply.
    @ViewBuilder
    private var inline: some View {
        switch content {
        case let .operation(summary):
            Text("widget.nextService.inline \(summary.operation.widgetTitle) \(Text(summary.word.widgetLabel))")
                .privacySensitive()
        case .empty, .unavailable:
            Label("widget.nextService.title", systemImage: "wrench.and.screwdriver")
        }
    }

    /// The Lock Screen renders this family in one vibrant tint, so the glyph's shape, not its colour, tells the state
    /// (REQ-DESIGN-001); the operation name joins the accent group.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch content {
            case let .operation(summary):
                summary.operation.widgetTitle
                    .font(PitTypography.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                HStack(spacing: 5) {
                    StatusGlyphView(glyph: summary.status.glyph, size: statusGlyphSize)
                    Text(summary.word.widgetLabel)
                }
                .lineLimit(1)
                summary.fact.widgetText
                    .foregroundStyle(PitColor.contentSecondary)
                    .lineLimit(1)
            case .empty:
                Text("widget.nextService.title")
                    .font(PitTypography.headline)
                    .widgetAccentable()
                Text("widget.nextService.empty.detail")
                    .lineLimit(2)
            case .unavailable:
                Text("widget.nextService.title")
                    .font(PitTypography.headline)
                    .widgetAccentable()
                Text("widget.nextService.unavailable")
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
        .accessibilityElement(children: .combine)
    }

    /// The mockup's small "Next service" frame: eyebrow, operation name and its status chip on top, the one fact at
    /// the bottom. The sparse states keep the same grammar with no chip, so no urgency is invented (core C2).
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("widget.nextService.title")
                .font(PitTypography.captionSmall.weight(.bold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(PitColor.contentSecondary)
                // Two lines, so the widget's name stays whole in Russian and Ukrainian.
                .lineLimit(2)
                .widgetAccentable()
            switch content {
            case let .operation(summary):
                summary.operation.widgetTitle
                    .font(PitTypography.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                StatusChip(Text(summary.word.widgetLabel), glyph: summary.status.glyph, color: summary.status.color)
                    // A chip wraps rather than truncates; in the fixed widget frame two lines keep it inside.
                    .lineLimit(2)
                Spacer(minLength: 0)
                summary.fact.widgetText
                    .font(PitTypography.caption)
                    .foregroundStyle(PitColor.contentSecondary)
                    .lineLimit(2)
            case .empty:
                Text("widget.nextService.empty.headline")
                    .font(PitTypography.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                Spacer(minLength: 0)
                Text("widget.nextService.empty.detail")
                    .font(PitTypography.caption)
                    .foregroundStyle(PitColor.contentSecondary)
            case .unavailable:
                Spacer(minLength: 0)
                Text("widget.nextService.unavailable")
                    .font(PitTypography.supporting)
                    .foregroundStyle(PitColor.contentSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .privacySensitive()
        .accessibilityElement(children: .combine)
    }
}

extension MaintenanceOperationID {
    /// The extension's own copy of Service's operation names; an ID without a name is shown verbatim.
    var widgetTitle: Text {
        switch self {
        case .engineOilService: Text("widget.operation.engineOilService")
        case .dsgService: Text("widget.operation.dsgService")
        case .awdCouplingService: Text("widget.operation.awdCouplingService")
        case .brakeFluid: Text("widget.operation.brakeFluid")
        case .cabinFilter: Text("widget.operation.cabinFilter")
        case .airFilter: Text("widget.operation.airFilter")
        case .sparkPlugs: Text("widget.operation.sparkPlugs")
        default: Text(verbatim: rawValue)
        }
    }
}

extension MaintenanceStatusWord {
    var widgetLabel: LocalizedStringKey {
        switch self {
        case .unknown: "widget.status.unknown"
        case .upToDate: "widget.status.upToDate"
        case .upToDateByDate: "widget.status.upToDate.byDate"
        case .approaching: "widget.status.approaching"
        case .approachingByDate: "widget.status.approaching.byDate"
        case .due: "widget.status.due"
        }
    }
}

extension ProgressFact {
    /// The short form of Service's progress line: the measure when there is one, otherwise the reason
    /// nothing is counted.
    var widgetText: Text {
        switch self {
        case .readingSuperseded: Text("widget.fact.nothingCounted")
        case .noBaseline: Text("widget.fact.noBaseline")
        case let .progress(measure?, _): measure.widgetText
        case let .progress(nil, block?): block.widgetText
        case .progress(nil, nil): DistanceBlock.mileageUnknown.widgetText
        }
    }
}

extension ProgressMeasure {
    var widgetText: Text {
        switch self {
        case let .kilometersAhead(kilometers): Text("widget.fact.inKm \(kilometers)")
        case let .kilometersPast(kilometers): Text("widget.fact.overKm \(kilometers)")
        case let .daysLeft(days): Text("widget.fact.inDays \(days)")
        case let .daysPast(days): Text("widget.fact.overDays \(days)")
        case .reached: Text("widget.fact.reached")
        case .almost: Text("widget.fact.almost")
        }
    }
}

extension DistanceBlock {
    var widgetText: Text {
        switch self {
        case .mileageUnknown: Text("widget.fact.mileageUnknown")
        case .mileageStale: Text("widget.fact.mileageStale")
        case .completionMileageMissing, .completionMissing: Text("widget.fact.distanceNotCounted")
        }
    }
}

#if DEBUG
    private typealias PreviewEntry = NextServiceTimelineProvider.Entry

    /// Fictional, like the gallery sample: a due operation shows the filled glyph and the due colour.
    private let dueSample = NextServiceContent.operation(NextServiceSummary(
        operation: .brakeFluid,
        status: .due,
        word: .due,
        fact: .progress(.daysPast(12), block: nil)
    ))

    #Preview(as: .systemSmall) {
        NextServiceWidget()
    } timeline: {
        PreviewEntry(date: .now, content: NextServiceTimelineProvider.sample)
        PreviewEntry(date: .now, content: dueSample)
        PreviewEntry(date: .now, content: .empty)
        PreviewEntry(date: .now, content: .unavailable)
    }

    #Preview(as: .accessoryRectangular) {
        NextServiceWidget()
    } timeline: {
        PreviewEntry(date: .now, content: NextServiceTimelineProvider.sample)
        PreviewEntry(date: .now, content: dueSample)
        PreviewEntry(date: .now, content: .empty)
        PreviewEntry(date: .now, content: .unavailable)
    }

    #Preview(as: .accessoryInline) {
        NextServiceWidget()
    } timeline: {
        PreviewEntry(date: .now, content: NextServiceTimelineProvider.sample)
        PreviewEntry(date: .now, content: .empty)
    }
#endif
