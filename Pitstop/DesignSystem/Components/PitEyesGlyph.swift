import SwiftUI

/// How one eye is drawn in a given state. Extracted from the view so the vocabulary can be checked:
/// two semantic states that look identical would make the motion meaningless.
struct PitEyeGeometry: Equatable {
    /// Eyelid: the eye's height. Closing is the lid coming down, not the eye shrinking.
    let height: CGFloat
    /// Gaze: where the highlight sits inside the eye.
    let pupil: CGPoint
    /// A closed eye shows no highlight, so nothing is drawn outside the lid.
    let showsPupil: Bool
    let dimmed: Bool
    /// A knock lifts both eyes; it is the only state told apart by position rather than the eye itself.
    let lift: CGFloat

    init(_ state: PitState) {
        showsPupil = state != .blink && state != .closedEyes
        dimmed = state == .hidden
        lift = state == .knock ? -3 : 0
        height = switch state {
        case .closedEyes: 1.5
        case .blink: 3
        case .startle: 17
        default: 15
        }
        // The highlight can travel 3.5 pt sideways inside a 9 pt eye before the lid clips it, so every
        // gaze stays inside that range and keeps the highlight fully visible.
        pupil = switch state {
        case .lookLeft: CGPoint(x: -3.5, y: 3)
        case .lookRight: CGPoint(x: 0, y: 3)
        case .lookUp: CGPoint(x: -1.75, y: 0)
        case .sideGaze: CGPoint(x: -3.5, y: 6)
        case .fixedGaze: CGPoint(x: -1.75, y: 4.5)
        case .startle: CGPoint(x: -1.75, y: 2)
        default: CGPoint(x: -1.75, y: 3)
        }
    }
}

/// Pit's face is two eyes; there is no body, mouth, or mascot (product-design.md). The shape alone
/// identifies the control, so the affordance survives Reduce Motion and VoiceOver unchanged.
struct PitEyesGlyph: View {
    var state: PitState = .resting

    private var geometry: PitEyeGeometry {
        PitEyeGeometry(state)
    }

    var body: some View {
        HStack(spacing: 5) {
            eye
            eye
        }
        .opacity(geometry.dimmed ? 0.35 : 1)
        .offset(y: geometry.lift)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Capsule()
            .fill(PitColor.contentPrimary)
            .frame(width: 9, height: geometry.height)
            .overlay(alignment: .topTrailing) {
                if geometry.showsPupil {
                    Circle()
                        .fill(PitColor.surfaceSecondary)
                        .frame(width: 3.5, height: 3.5)
                        .padding(2)
                        .offset(x: geometry.pupil.x, y: geometry.pupil.y)
                }
            }
            .clipShape(Capsule())
    }
}
