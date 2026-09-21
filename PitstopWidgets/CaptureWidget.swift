import SwiftUI
import WidgetKit

/// A data-free Home Screen and Lock Screen widget whose tap opens the Pit sheet through `pitstop://pit`
/// (ADR 0025, REQ-CAPTURE-023). It shows the capture action, not the app icon, and never reads the store.
struct CaptureWidget: Widget {
    static let kind = "dev.vil4max.pitstop.widgets.capture"
    /// The same glyph as the Open Pit App Shortcut (ADR 0024).
    static let symbol = "square.and.pencil"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CaptureTimelineProvider()) { _ in
            CaptureWidgetView()
                .widgetURL(CaptureSurface.pit.url)
        }
        .configurationDisplayName("widget.capture.title")
        .description("widget.capture.description")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// One static entry that never changes, so the widget never asks for a reload.
struct CaptureTimelineProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
    }

    func placeholder(in _: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: CaptureWidget.symbol)
                    .font(.title2)
                    .widgetAccentable()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("widget.capture.action"))
            .containerBackground(for: .widget) {}
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: CaptureWidget.symbol)
                    .font(.title)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text("widget.capture.action")
                    .font(.headline)
                Text("widget.capture.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
