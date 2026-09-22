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

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
                .containerBackground(for: .widget) {}
        default:
            small
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

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

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch content {
            case let .operation(summary):
                summary.operation.widgetTitle
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Label(summary.word.widgetLabel, systemImage: summary.status.systemImage)
                    .lineLimit(1)
                summary.fact.widgetText
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .empty:
                Text("widget.nextService.title")
                    .font(.headline)
                    .widgetAccentable()
                Text("widget.nextService.empty.detail")
                    .lineLimit(2)
            case .unavailable:
                Text("widget.nextService.title")
                    .font(.headline)
                    .widgetAccentable()
                Text("widget.nextService.unavailable")
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
        .accessibilityElement(children: .combine)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("widget.nextService.title", systemImage: "wrench.and.screwdriver")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            Spacer(minLength: 0)
            switch content {
            case let .operation(summary):
                summary.operation.widgetTitle
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Label(summary.word.widgetLabel, systemImage: summary.status.systemImage)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                summary.fact.widgetText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            case .empty:
                Text("widget.nextService.empty.headline")
                    .font(.headline)
                Text("widget.nextService.empty.detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unavailable:
                Text("widget.nextService.unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
