import SwiftUI
import WidgetKit

/// PitStop's system entries outside the app. The control and the capture widget only open the Pit sheet and
/// show no car data (ADR 0025); the next-service widget reads the store read-only and opens Service (ADR 0036).
@main
struct PitstopWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenPitControl()
        CaptureWidget()
        NextServiceWidget()
    }
}
