import Foundation
import Observation

/// Where Pit's capture surface is open. Pit is on screen in the utility layer and inside every other sheet
/// (REQ-UTILITY-012, REQ-PIT-026), and there is one capture, so every entry opens and closes it here: one
/// place decides that a second capture cannot start and what closing it leaves behind.
@MainActor
@Observable
final class PitCaptureEntry {
    enum Host: Hashable {
        /// The root's own sheet, opened from the utility layer or by an "Open Pit" request.
        case utilityLayer
        /// Opened from Pit inside another sheet, which stays presented underneath with its input.
        case sheet(UUID)
    }

    private(set) var host: Host?

    @ObservationIgnored let capture: PitCaptureViewModel
    @ObservationIgnored let question: PitQuestionViewModel

    init(capture: PitCaptureViewModel, question: PitQuestionViewModel) {
        self.capture = capture
        self.question = question
    }

    var isOpen: Bool {
        host != nil
    }

    var isOverSheet: Bool {
        if case .sheet = host {
            true
        } else {
            false
        }
    }

    /// Returns whether the capture surface opened for `host`. It never replaces a capture open elsewhere.
    @discardableResult
    func open(from host: Host) -> Bool {
        guard self.host == nil else { return false }
        self.host = host
        return true
    }

    /// However the surface closed, by Close or a swipe: an unsent capture is cancelled, never left half-done, and
    /// an answered question is acknowledged. An unanswered question is not: Pit keeps knocking (ADR 0017).
    func close(from host: Host) {
        guard self.host == host else { return }
        self.host = nil
        capture.cancel()
        question.acknowledge()
    }
}
