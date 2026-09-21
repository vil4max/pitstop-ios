import AppIntents
import SwiftUI
import WidgetKit

/// "Open Pit" for Control Center, the Lock Screen, and the Action button (ADR 0025). Its action is the
/// shared `OpenPitIntent`, an `OpenIntent`, which is the documented way for a control to open the app.
struct OpenPitControl: ControlWidget {
    static let kind = "dev.vil4max.pitstop.widgets.openPit"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenPitIntent()) {
                Label("control.openPit.title", systemImage: CaptureWidget.symbol)
            }
        }
        .displayName("control.openPit.title")
        .description("control.openPit.description")
    }
}
