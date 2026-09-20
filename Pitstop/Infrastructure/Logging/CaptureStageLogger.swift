import Foundation
import os

/// DEBUG diagnostics for the capture pipeline (ADR 0003). Release builds create no logger and emit nothing.
struct CaptureStageLogger: CaptureStageObserving {
    #if DEBUG
        private static let logger = AppLog.logger(category: "capture.pipeline")
    #endif

    func record(_ event: CaptureStageEvent) {
        #if DEBUG
            let kind = event.proposalKind?.rawValue ?? "-"
            let outcome = event.outcome?.rawValue ?? "-"
            Self.logger.debug(
                "\(event.stage.rawValue, privacy: .public) id=\(event.correlationID.uuidString, privacy: .public) source=\(event.source.rawValue, privacy: .public) kind=\(kind, privacy: .public) outcome=\(outcome, privacy: .public)"
            )
        #endif
    }
}
