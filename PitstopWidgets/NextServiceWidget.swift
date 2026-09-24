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
    /// A status glyph drawn without a chip (the Lock Screen, and the small widget's last resort) grows with the text,
    /// as a chip's glyph does.
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

    /// What VoiceOver reads for the small and rectangular families, whichever layout is shown: a line dropped for
    /// room leaves the screen, not the spoken summary. `ViewThatFits` keeps only the chosen layout in the
    /// accessibility tree, so combining its children would silence the dropped lines.
    private var spokenSummary: Text {
        switch content {
        case let .operation(summary):
            Text("\(summary.operation.widgetTitle), \(Text(summary.word.widgetLabel)), \(summary.fact.widgetText)")
        case .empty:
            Text("\(Text("widget.nextService.empty.headline")), \(Text("widget.nextService.empty.detail"))")
        case .unavailable:
            Text("widget.nextService.unavailable")
        }
    }

    /// The Lock Screen renders this family in one vibrant tint, so the glyph's shape, not its colour, tells the state
    /// (REQ-DESIGN-001); the operation name joins the accent group. When the text does not fit, lines go by priority
    /// instead of being clipped (owner, FU-2): the fact goes first, then the status word, leaving its glyph; the name
    /// and the status always stay.
    private var rectangular: some View {
        Group {
            switch content {
            case let .operation(summary):
                ViewThatFits(in: .vertical) {
                    rectangularOperation(summary, showsFact: true)
                    rectangularOperation(summary, showsFact: false)
                    rectangularOperation(summary, showsFact: false, showsWord: false)
                    rectangularOperation(summary, showsFact: false, showsWord: false, nameLines: 1)
                }
            case .empty:
                ViewThatFits(in: .vertical) {
                    rectangularSentence("widget.nextService.empty.detail", showsTitle: true)
                    rectangularSentence("widget.nextService.empty.detail", showsTitle: false)
                }
            case .unavailable:
                ViewThatFits(in: .vertical) {
                    rectangularSentence("widget.nextService.unavailable", showsTitle: true)
                    rectangularSentence("widget.nextService.unavailable", showsTitle: false)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .privacySensitive()
    }

    /// Without the word, the status is its glyph alone (VoiceOver still reads the word in `spokenSummary`), leading the
    /// name as on the small widget: on two whole lines when they fit the slot, otherwise on one line that may shrink.
    private func rectangularOperation(
        _ summary: NextServiceSummary,
        showsFact: Bool,
        showsWord: Bool = true,
        nameLines: Int = 2
    ) -> some View {
        let name = summary.operation.widgetTitle
            .font(PitTypography.headline)
            .widgetAccentable()
        return VStack(alignment: .leading, spacing: 1) {
            if showsWord {
                name
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    StatusGlyphView(glyph: summary.status.glyph, size: statusGlyphSize)
                    // `ViewThatFits` measures height only, so the word wraps rather than being cut sideways: a word
                    // that needs more room makes this layout taller, and the widget moves on (REQ-GRAMMAR-003).
                    Text(summary.word.widgetLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    StatusGlyphView(glyph: summary.status.glyph, size: statusGlyphSize)
                    // Two lines report their full height, so a slot too short for them rejects this layout.
                    name
                        .lineLimit(nameLines)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: nameLines > 1)
                }
            }
            if showsFact {
                summary.fact.widgetText
                    .foregroundStyle(PitColor.contentSecondary)
                    .lineLimit(1)
            }
        }
    }

    /// The sparse and unreadable states keep their sentence; the widget's name above it goes first.
    private func rectangularSentence(_ sentence: LocalizedStringKey, showsTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if showsTitle {
                Text("widget.nextService.title")
                    .font(PitTypography.headline)
                    .widgetAccentable()
            }
            Text(sentence)
                .lineLimit(showsTitle ? 2 : 3)
                .minimumScaleFactor(showsTitle ? 1 : 0.5)
        }
    }

    /// The mockup's small "Next service" frame: eyebrow, operation name and its status chip on top, the one fact at
    /// the bottom. When the text does not fit (large text sizes, long names), lines go by priority instead of being
    /// clipped (owner, FU-2): the eyebrow first, then the fact, then the status word, leaving the name (up to three
    /// lines) and the status glyph; the name and the status always stay, and a tap opens Service for the rest. The
    /// sparse states keep the same grammar with no chip, so no urgency is invented (core C2), and keep their sentence.
    private var small: some View {
        Group {
            switch content {
            case let .operation(summary):
                ViewThatFits(in: .vertical) {
                    smallOperation(summary, showsEyebrow: true, showsFact: true)
                    smallOperation(summary, showsEyebrow: false, showsFact: true)
                    smallOperation(summary, showsEyebrow: false, showsFact: false)
                    smallOperation(summary, showsEyebrow: false, showsFact: false, showsWord: false)
                }
            case .empty:
                ViewThatFits(in: .vertical) {
                    smallEmpty(showsEyebrow: true)
                    smallEmpty(showsEyebrow: false)
                }
            case .unavailable:
                ViewThatFits(in: .vertical) {
                    smallUnavailable(showsEyebrow: true)
                    smallUnavailable(showsEyebrow: false)
                }
            }
        }
        // The chosen layout starts at the top of the widget. `minHeight: 0` keeps the frame at the widget's height;
        // with a maximum alone it would grow to a taller layout and be centred.
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .privacySensitive()
    }

    private var smallEyebrow: some View {
        Text("widget.nextService.title")
            .font(PitTypography.captionSmall.weight(.bold))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(PitColor.contentSecondary)
            // Two lines, so the widget's name stays whole in Russian and Ukrainian.
            .lineLimit(2)
            .widgetAccentable()
    }

    /// Without the word (the last resort), the status is its glyph alone, in the status colour; VoiceOver still reads
    /// the word in `spokenSummary`. The glyph leads the name, so the name keeps the widget's whole height for up to
    /// three lines.
    private func smallOperation(
        _ summary: NextServiceSummary,
        showsEyebrow: Bool,
        showsFact: Bool,
        showsWord: Bool = true
    ) -> some View {
        let name = summary.operation.widgetTitle
            .font(PitTypography.headline)
            .foregroundStyle(PitColor.contentPrimary)
        return VStack(alignment: .leading, spacing: 4) {
            if showsEyebrow {
                smallEyebrow
            }
            if showsWord {
                name
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                // The chip wraps and is never truncated (REQ-GRAMMAR-003): a word that does not fit makes this layout
                // too tall, and the widget moves on to the glyph alone.
                StatusChip(Text(summary.word.widgetLabel), glyph: summary.status.glyph, color: summary.status.color)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    StatusGlyphView(glyph: summary.status.glyph, size: statusGlyphSize)
                        .foregroundStyle(summary.status.color)
                    name
                        .lineLimit(3)
                        // The name is the main information left, so it may shrink further to stay whole.
                        .minimumScaleFactor(0.6)
                }
            }
            if showsFact {
                Spacer(minLength: 0)
                summary.fact.widgetText
                    .font(PitTypography.caption)
                    .foregroundStyle(PitColor.contentSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func smallEmpty(showsEyebrow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsEyebrow {
                smallEyebrow
            }
            Text("widget.nextService.empty.headline")
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.contentPrimary)
                .minimumScaleFactor(showsEyebrow ? 1 : 0.5)
            Spacer(minLength: 0)
            Text("widget.nextService.empty.detail")
                .font(PitTypography.caption)
                .foregroundStyle(PitColor.contentSecondary)
                .minimumScaleFactor(showsEyebrow ? 1 : 0.5)
        }
    }

    private func smallUnavailable(showsEyebrow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsEyebrow {
                smallEyebrow
            }
            Spacer(minLength: 0)
            Text("widget.nextService.unavailable")
                .font(PitTypography.supporting)
                .foregroundStyle(PitColor.contentSecondary)
                .minimumScaleFactor(showsEyebrow ? 1 : 0.5)
        }
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
