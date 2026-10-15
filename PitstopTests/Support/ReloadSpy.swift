@testable import Pitstop
import Synchronization

/// Counts widget reload requests instead of asking WidgetKit.
final class ReloadSpy: NextServiceReloading {
    private let count = Mutex(0)

    func reloadNextService() {
        count.withLock { $0 += 1 }
    }

    var requests: Int {
        count.withLock { $0 }
    }
}
