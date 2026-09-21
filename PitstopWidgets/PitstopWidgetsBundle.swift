import SwiftUI
import WidgetKit

/// PitStop's system entries outside the app (ADR 0025). Both only open the Pit sheet and show no car data:
/// the extension has no access to the store.
@main
struct PitstopWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenPitControl()
        CaptureWidget()
    }
}
