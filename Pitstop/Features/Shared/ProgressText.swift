import SwiftUI

/// One wording for how far a tracked point is, shared by Service and Road so the same standing never
/// reads two ways. The keys live in the neutral `progress.*` namespace, owned by neither screen.
enum ProgressText {
    static func kilometersAhead(_ kilometers: Int) -> Text {
        Text("progress.inKm \(kilometers)")
    }

    static func kilometersPast(_ kilometers: Int) -> Text {
        Text("progress.overKm \(kilometers)")
    }

    static func daysLeft(_ days: Int) -> Text {
        Text("progress.daysLeft \(days)")
    }

    static func daysPast(_ days: Int) -> Text {
        Text("progress.daysPast \(days)")
    }

    static var reached: Text {
        Text("progress.reached")
    }

    static var almost: Text {
        Text("progress.almost")
    }

    /// Why there is no number; the reason is said as it is.
    static func blocked(_ block: DistanceBlock) -> Text {
        switch block {
        case .mileageStale: Text("progress.mileageStale")
        case .mileageUnknown: Text("progress.mileageUnknown")
        case .completionMileageMissing: Text("progress.completionMileageMissing")
        case .completionMissing: Text("progress.completionMissing")
        }
    }
}
