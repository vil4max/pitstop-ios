import CoreGraphics
@testable import Pitstop
import Synchronization

/// Answers every lift with a scripted cut-out, or with nothing as when no subject is found, and records the
/// size of each image it was given.
final class FakeSubjectLifter: SubjectLifter {
    private let cutOut: CGImage?
    private let inputs = Mutex<[CGSize]>([])

    init(cutOut: CGImage?) {
        self.cutOut = cutOut
    }

    var liftedSizes: [CGSize] {
        inputs.withLock { $0 }
    }

    func lift(_ image: CGImage) async -> CGImage? {
        inputs.withLock { $0.append(CGSize(width: image.width, height: image.height)) }
        return cutOut
    }
}
