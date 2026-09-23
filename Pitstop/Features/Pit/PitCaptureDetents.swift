import SwiftUI

/// The capture sheet's heights (pit-behavior-and-motion.md, "Capture"). Both stay available at every text size;
/// only the one the sheet opens at depends on it.
enum PitCaptureDetents {
    static let available: Set<PresentationDetent> = [.medium, .large]

    /// At accessibility text sizes the medium detent leaves the composer and its action under the keyboard, so the
    /// sheet opens large there (REQ-PIT-025).
    static func initial(for size: DynamicTypeSize) -> PresentationDetent {
        size.isAccessibilitySize ? .large : .medium
    }
}
