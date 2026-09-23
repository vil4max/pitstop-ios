import SwiftUI

/// What the capture sheet shows: exactly one moment, never a history of earlier turns (REQ-PIT-021). The sheet
/// renders from this single value; nothing from a finished or cancelled capture survives into it.
enum PitSheetMoment: Equatable {
    /// Writing. Pit's own question, or what answering it recorded, sits above the composer (ADR 0017).
    case composing(PitComposerNotice)
    case working
    case confirming(PendingCapture)
    case clarifying(ClarificationRequest)
    case saved(PitDestination, preservedRaw: Bool)

    /// Pit's pending question belongs to the composing moment only: while the capture itself confirms or asks
    /// its one clarification, the question waits, so the sheet never asks two things at once (REQ-PIT-003).
    init(capture: PitCapturePhase, question: PitQuestionPhase) {
        switch capture {
        case .composing: self = .composing(PitComposerNotice(question))
        case .working: self = .working
        case let .confirming(pending): self = .confirming(pending)
        case let .clarifying(request): self = .clarifying(request)
        case let .saved(destination, preservedRaw): self = .saved(destination, preservedRaw: preservedRaw)
        }
    }

    /// Where the composer's Remember action goes and how it looks; `nil` outside the composing moment.
    ///
    /// Placement: while the user writes, Remember is pinned to the sheet bottom, so it stays above the keyboard
    /// (REQ-PIT-025). With Pit's question pending, below the accessibility sizes it stays under the composer, so it
    /// does not cover the card at the medium detent; at accessibility sizes the sheet is at the large detent and the
    /// composer alone fills the space above the keyboard, so it stays pinned.
    ///
    /// Style: the sheet has one prominent action (REQ-PIT-027). With Pit's question pending, that is the question's
    /// Save, as the mockup's "Pit asked" frame draws it, so Remember is quiet at every text size; otherwise Remember
    /// is the prominent action.
    func rememberAction(at size: DynamicTypeSize) -> PitRememberAction? {
        switch self {
        case .composing(.question):
            PitRememberAction(placement: size.isAccessibilitySize ? .pinned : .inline, isProminent: false)
        case .composing:
            PitRememberAction(placement: .pinned, isProminent: true)
        case .working, .confirming, .clarifying, .saved:
            nil
        }
    }

    /// The title names the moment, so the sheet needs no transcript to say where the user is.
    var title: PitMomentTitle {
        switch self {
        case .composing, .working: .remember
        case .confirming: .isThisRight
        case .clarifying: .oneThing
        case .saved: .saved
        }
    }
}

/// The composer's Remember action: where it sits and whether it is the sheet's prominent action.
struct PitRememberAction: Equatable {
    enum Placement: Equatable {
        /// At the sheet bottom, above the keyboard.
        case pinned
        /// Under the composer, in the scrolling content.
        case inline
    }

    let placement: Placement
    let isProminent: Bool
}

/// What sits above the composer while the user writes.
enum PitComposerNotice: Equatable {
    case none
    case question(PitAskedQuestion)
    /// The reading just saved from Pit's question; it stays until the sheet closes.
    case answered(kilometers: Int)

    init(_ phase: PitQuestionPhase) {
        switch phase {
        case .silent: self = .none
        case let .asking(question), let .working(question): self = .question(question)
        case let .answered(kilometers): self = .answered(kilometers: kilometers)
        }
    }
}

enum PitMomentTitle: Equatable {
    case remember
    case isThisRight
    case oneThing
    case saved

    var key: LocalizedStringKey {
        switch self {
        case .remember: "pit.title"
        case .isThisRight: "pit.confirm.title"
        case .oneThing: "pit.moment.clarifying"
        case .saved: "pit.saved.interpreted"
        }
    }
}
